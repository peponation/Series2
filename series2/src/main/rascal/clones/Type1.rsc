module clones::Type1

import lang::java::m3::AST;
import Node;
import List;
import Map;

import IO;

// Simple clone class container
data CloneClass = cloneClass(int id, list[loc] members);

// Aggregated statistics for a project
data CloneStats = cloneStats(
    int totalLoc,                // total physical LOC of the project
    int duplicatedLoc,           // total LOC that are part of clones
    real duplicatedPercentage,   // duplicatedLoc / totalLoc * 100
    int cloneCount,              // total number of clone fragments (members)
    int cloneClassCount,         // number of clone classes
    int biggestCloneLines,       // size (in lines) of the largest single clone fragment
    loc  biggestCloneLocation,   // where that largest clone fragment is
    int biggestCloneClassSize,   // largest clone class size (number of members)
    int biggestCloneClassId      // id of that largest clone class
);


public str toJsonStats(CloneStats s) {
    int totalLoc;
    int duplicatedLoc;
    real duplicatedPercentage;
    int cloneCount;
    int cloneClassCount;
    int biggestCloneLines;
    loc biggestCloneLocation;
    int biggestCloneClassSize;
    int biggestCloneClassId;

    // Destructure the CloneStats value
    switch (s) {
        case cloneStats(
            int t,
            int d,
            real p,
            int c,
            int cc,
            int bcl,
            loc bl,
            int bccs,
            int bccid
        ): {
            totalLoc             = t;
            duplicatedLoc        = d;
            duplicatedPercentage = p;
            cloneCount           = c;
            cloneClassCount      = cc;
            biggestCloneLines    = bcl;
            biggestCloneLocation = bl;
            biggestCloneClassSize = bccs;
            biggestCloneClassId   = bccid;
        }
    }

    str json = "{ ";
    json += "\"totalLoc\": <totalLoc>, ";
    json += "\"duplicatedLoc\": <duplicatedLoc>, ";
    json += "\"duplicatedPercentage\": <duplicatedPercentage>, ";
    json += "\"cloneCount\": <cloneCount>, ";
    json += "\"cloneClassCount\": <cloneClassCount>, ";
    json += "\"biggestCloneLines\": <biggestCloneLines>, ";
    json += "\"biggestCloneLocation\": \"<biggestCloneLocation>\", ";
    json += "\"biggestCloneClassSize\": <biggestCloneClassSize>, ";
    json += "\"biggestCloneClassId\": <biggestCloneClassId>";
    json += " }";

    return json;
}



/**
 * Collect all method bodies (as <loc, Statement>) from the given ASTs.
 */
public list[tuple[loc, Statement]] getMethodBodies(list[Declaration] asts) {
    list[tuple[loc, Statement]] bodies = [];

    // Walk over all ASTs (all compilation units)
    visit (asts) {
        // Match a method declaration that has a Statement body `impl`
        case \method(_, _, _, _, _, _, Statement impl): {
            if (impl.src?) {                      // make sure the body has a source location
                bodies += [<impl.src, impl>];     // store <location, body-ast>
            }
        }
    }

    return bodies;
}

// Returns true if membersA is a strict subset of membersB:
// - every location in A is also in B
// - and A has fewer elements than B
bool isStrictSubset(list[loc] membersA, list[loc] membersB) {
    // If A is not smaller than B, it cannot be a strict subset
    if (size(membersA) >= size(membersB)) {
        return false;
    }

    // Check that every location in A appears in B
    for (loc l <- membersA) {
        if (l notin membersB) {
            return false;
        }
    }

    return true;
}

/**
 * Remove clone classes that are strictly included in others (subsumption).
 *
 * A class C_i is removed if its members list is a strict subset
 * of the members of some other class C_j.
 */
public list[CloneClass] removeSubsumedClasses(list[CloneClass] classes) {
    set[int] subsumed = {};        // indices of classes to drop
    int n = size(classes);

    // Compare each pair of classes (i, j)
    for (int i <- [0..n-1]) {
        if (i in subsumed) {
            continue;
        }

        CloneClass ci = classes[i];

        for (int j <- [0..n-1]) {
            if (i == j) {
                continue;
            }
            if (j in subsumed) {
                continue;
            }

            CloneClass cj = classes[j];

            // Pattern match to get the member lists
            list[loc] membersI;
            list[loc] membersJ;

            switch (ci) {
                case cloneClass(_, list[loc] msI): {
                    membersI = msI;
                }
            }
            switch (cj) {
                case cloneClass(_, list[loc] msJ): {
                    membersJ = msJ;
                }
            }

            // If Ci is strictly included in Cj, mark Ci as subsumed
            if (isStrictSubset(membersI, membersJ)) {
                subsumed += { i };
                break;  // no need to compare Ci with other classes
            }
        }
    }

    // Build the result list without the subsumed classes
    list[CloneClass] result = [];
    for (int k <- [0..n-1]) {
        if (k notin subsumed) {
            result += [classes[k]];
        }
    }

    return result;
}


public CloneStats computeCloneStats(list[CloneClass] classes, int totalLoc) {
    int cloneClassCount = size(classes);
    int cloneCount = 0;

    // Track unique clone fragments so we don't double-count lines
    set[loc] uniqueMembers = {};

    int biggestCloneLines = 0;
    loc biggestCloneLocation = |unknown:///|;

    int biggestCloneClassSize = 0;
    int biggestCloneClassId = -1;

    // Walk over all clone classes
    for (CloneClass c <- classes) {
        int classId;
        list[loc] members;

        // Destructure CloneClass
        switch (c) {
            case cloneClass(int cid, list[loc] ms): {
                classId = cid;
                members = ms;
            }
        }

        // Update cloneCount (each member is one clone fragment)
        cloneCount += size(members);

        // Update biggest clone class (in members)
        if (size(members) > biggestCloneClassSize) {
            biggestCloneClassSize = size(members);
            biggestCloneClassId = classId;
        }

        // Process each member location
        for (loc l <- members) {
            uniqueMembers += { l };

            int lines = l.end.line - l.begin.line + 1;
            if (lines > biggestCloneLines) {
                biggestCloneLines = lines;
                biggestCloneLocation = l;
            }
        }
    }

    // Sum the LOC of all unique clone fragments
    int duplicatedLoc = 0;
    for (loc l <- uniqueMembers) {
        duplicatedLoc += l.end.line - l.begin.line + 1;
    }

    real duplicatedPercentage =
        totalLoc == 0 ? 0.0 : (duplicatedLoc * 100.0) / totalLoc;

    return cloneStats(
        totalLoc,
        duplicatedLoc,
        duplicatedPercentage,
        cloneCount,
        cloneClassCount,
        biggestCloneLines,
        biggestCloneLocation,
        biggestCloneClassSize,
        biggestCloneClassId
    );
}





/**
 * AST-based Type 1 clone detection on method bodies.
 * Type 1 = identical normalized AST subtrees (locations removed).
 */
public list[CloneClass] detectType1MethodClonesAst(list[Declaration] asts, int minLines) {
    // 1. Collect all method bodies (location + AST)
    list[tuple[loc, Statement]] bodies = getMethodBodies(asts);

    // 2. Map from normalized AST -> all locations that share that structure
    map[value, list[loc]] buckets = ();

    for (<loc bodyLoc, Statement impl> <- bodies) {
        // Filter by minimum number of lines in the original body
        int span = bodyLoc.end.line - bodyLoc.begin.line + 1;
        if (span < minLines) {
            continue;
        }

        // Normalize AST: remove locations and other annotations
        value normalized = unsetRec(impl);

        // Group by normalized AST
        if (buckets[normalized]?) {
            buckets[normalized] += [bodyLoc];
        } else {
            buckets[normalized] = [bodyLoc];
        }
    }

    // 3. Turn buckets into CloneClass values (only keep real clones: ≥ 2 members)
    list[CloneClass] classes = [];
    int nextId = 1;

    for (value key <- buckets) {
        list[loc] members = buckets[key];
        if (size(members) >= 2) {
            classes += [cloneClass(nextId, members)];
            nextId += 1;
        }
    }

    return classes;
}


// Convert a single CloneClass to a JSON object string
str toJsonCloneClass(CloneClass c) {
    int id;
    list[loc] members = [];

    // Pattern match on the CloneClass value
    switch (c) {
        case cloneClass(int cid, list[loc] ms): {
            id = cid;
            members = ms;
        }
    }

    // Build JSON array for the member locations
    str membersJson = "[";
    bool first = true;
    for (loc l <- members) {
        if (!first) {
            membersJson += ", ";
        }
        first = false;
        // Store the URI form of the location as a JSON string
        membersJson += "\"<l>\"";
    }
    membersJson += "]";

    // Return JSON object for this clone class
    return "{ \"id\": <id>, \"members\": " + membersJson + " }";
}


/**
 * Write the given Type 1 clone classes to a JSON file.
 *
 * Example JSON structure:
 * [
 *   { "id": 1, "members": ["|java+compilationUnit:///...|", "..."] },
 *   { "id": 2, "members": ["..."] }
 * ]
 */
public void writeCloneReportToJson(list[CloneClass] classes, CloneStats stats, loc outFile) {
    // 1. Stats part
    str statsJson = toJsonStats(stats);

    // 2. Clone classes array
    str classesJson = "[\n";
    int n = size(classes);
    int idx = 0;
    for (CloneClass c <- classes) {
        idx += 1;
        classesJson += toJsonCloneClass(c);
        if (idx < n) {
            classesJson += ",\n";
        }
    }
    classesJson += "\n]";

    // 3. Wrap into a top-level JSON object
    str json = "{\n";
    json += "  \"stats\": " + statsJson + ",\n";
    json += "  \"cloneClasses\": " + classesJson + "\n";
    json += "}\n";

    writeFile(outFile, json);
}


