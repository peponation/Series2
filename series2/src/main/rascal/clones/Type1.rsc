module clones::Type1

import lang::java::m3::AST;
import Node;
import List;
import Map;

import IO;

// Simple clone class container
data CloneClass = cloneClass(int id, list[loc] members);

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
public void writeType1ClonesToJson(list[CloneClass] classes, loc outFile) {
    str json = "[\n";

    int n = size(classes);
    int idx = 0;

    for (CloneClass c <- classes) {
        idx += 1;
        json += toJsonCloneClass(c);
        if (idx < n) {
            json += ",\n";
        }
    }

    json += "\n]\n";

    // Actually write the JSON text to the given file location
    writeFile(outFile, json);
}
