module Main

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;
import Map;
import util::Math;

import clones::Type1;

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


int main(int testArgument=0) {
    //asts = getASTs(|home:///Documents/School/Master/Software-Evolution/Series2/smallsql0.21_src|);
    //asts = getASTs(|home:///Documents/School/Master/Software-Evolution/Series2/hsqldb-2.3.1|);
    //asts = getASTs(|home:///Documents/School/Master/Software-Evolution/Series2/CloneTesting|);

    //It is better to do it like this by adding the projects to the workspace instead using your own directory
    // asts = getASTs(|project://smallsql0.21_src/|);
    astsTwo = getASTs(|project://hsqldb-2.3.1/|);
    // astsThree = getASTs(|project://CloneTesting|);


    int fileCount = size(astsTwo);
    int ploc = countPhysicalLocFromAsts(astsTwo);
    println("File count: <fileCount>");
    println("Physical LOC: <ploc>");

    // --- Type 1 clone detection ---
    int minLines = 2; // choose what you consider "big enough"
    list[CloneClass] type1Clones = detectType1Clones(astsTwo, minLines);
    println("Found <size(type1Clones)> Type 1 clone classes (\>= <minLines> lines).");

    // Optionally print some example clone classes
    for (cloneClass(id, occs) <- type1Clones[0..min(5, size(type1Clones))]) {
        println("Clone class <id> with <size(occs)> occurrences:");
        for (loc l <- occs) {
            println("  <l>");
        }
    }

    return 0;
}

