module Main

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;
import Map;
import util::Math;

import Node;

data CloneClass = cloneClass(int id, list[loc] members);

// Standard AST function
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

int countPhysicalLocFromAsts(list[Declaration] asts) {
    int total = 0;
    for (decl <- asts) {
        total += size(readFileLines(decl.src));
    }
    return total;
}

// Cleans a code fragment by removing empty lines, comments and whitespace
list[str] cleanCodeFragment(str codeFragment) {
    list[str] lines = split(codeFragment, "\n");
    list[str] cleanedLines = [];

    for (line <- lines) {
        str trimmed = trim(line);
        if (trimmed != "" && !startsWith(trimmed, "//") && !startsWith(trimmed, "/*") && !startsWith(trimmed, "*") && !endsWith(trimmed, "*/")) {
            cleanedLines += [trimmed];
        }
    }

    return cleanedLines;
}

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



public str canonicalMethodBody(loc bodyLoc) {
    // 1. Read the lines belonging to this method body
    list[str] lines = readFileLines(bodyLoc);

    // 2. Combine them into a single code fragment string
    str codeFragment = "";
    for (str line <- lines) {
        codeFragment += line + "\n";
    }

    // 3. Clean the fragment using your existing function
    list[str] cleanedLines = cleanCodeFragment(codeFragment);

    // 4. Turn cleaned lines into a canonical string representation
    str canonical = "";
    for (str cl <- cleanedLines) {
        canonical += cl + "\n";
    }

    return canonical;
}

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

        // Group by normalized AST (REAL AST-based key!)
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




int main() {
    //It is better to do it like this by adding the projects to the workspace instead using your own directory
    asts = getASTs(|project://smallsql0.21_src/|);
    // astsTwo = getASTs(|project://hsqldb-2.3.1/|);
    // asts = getASTs(|project://CloneTesting|);


    int fileCount = size(asts);
    int ploc = countPhysicalLocFromAsts(asts);
    println("File count: <fileCount>");
    println("Physical LOC: <ploc>");

    // --- Type 1 clone detection ---

    // --- AST-based Type 1 clone detection (method-level) ---
    int minLines = 2; // start small for CloneTesting, you can increase later
    list[CloneClass] type1 = detectType1MethodClonesAst(asts, minLines);
    println("AST-based Type 1 method clone classes (\>= <minLines> lines): <size(type1)>");

    int limit = min(5, size(type1));
    for (CloneClass c <- type1[0..limit]) {
        println("Clone class <c.id> with <size(c.members)> occurrences:");
        for (loc l <- c.members) {
            println("  <l>");
        }
    }



    return 0;
}

