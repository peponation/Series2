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


public void printCloneStats(CloneStats s) {
    switch (s) {
        case cloneStats(
            int totalLoc,
            int duplicatedLoc,
            real duplicatedPercentage,
            int cloneCount,
            int cloneClassCount,
            int biggestCloneLines,
            loc biggestCloneLocation,
            int biggestCloneClassSize,
            int biggestCloneClassId
        ): {
            println("=== Clone Statistics ===");
            println("Total LOC: <totalLoc>");
            println("Duplicated LOC: <duplicatedLoc> (<duplicatedPercentage>% of total)");
            println("Number of clone classes: <cloneClassCount>");
            println("Number of clones (fragments): <cloneCount>");
            println("Biggest clone (in lines): <biggestCloneLines> at <biggestCloneLocation>");
            println("Biggest clone class (members): <biggestCloneClassSize> (class id <biggestCloneClassId>)");
        }
    }
}


public str codeFromLoc(loc fragment) {
    list[str] lines = readFileLines(fragment);
    str result = "";
    for (str line <- lines) {
        result += line + "\n";
    }
    return result;
}

public void printExampleClones(list[CloneClass] classes, int maxClasses) {
    int classLimit = min(maxClasses, size(classes));

    for (int i <- [0..classLimit-1]) {
        CloneClass c = classes[i];

        int id;
        list[loc] members = [];

        // Destructure the CloneClass
        switch (c) {
            case cloneClass(int cid, list[loc] ms): {
                id = cid;
                members = ms;
            }
        }

        println("=== Example clone class <id> (members: <size(members)>) ===");

        int memberLimit = size(members);  // 👈 show *all* members
        for (int j <- [0..memberLimit-1]) {
            loc l = members[j];
            println("--- Member <j + 1> at <l> ---");
            println(codeFromLoc(l));
        }

        println(""); // blank line between classes
    }
}




int main() {
    asts = getASTs(|project://smallsql0.21_src/|);
    // asts = getASTs(|project://CloneTesting|);
    // astsTwo = getASTs(|project://hsqldb-2.3.1/|);

    int fileCount = size(asts);
    int ploc = countPhysicalLocFromAsts(asts);
    println("File count: <fileCount>");
    println("Physical LOC: <ploc>");

    // --- AST-based Type 1 clone detection ---
    int minLines = 4;
    list[CloneClass] rawType1 = detectType1MethodClonesAst(asts, minLines);
    list[CloneClass] type1 = removeSubsumedClasses(rawType1);
    println("AST-based Type 1 method clone classes after subsumption (\>= <minLines> lines): <size(type1)>");

    // Example clones (printed with actual code)
    printExampleClones(type1, 3);  // e.g., show 3 clone classes


    // --- Statistics ---
    CloneStats stats = computeCloneStats(type1, ploc);
    printCloneStats(stats);

    // JSON output: stats + clone classes together
    loc outFile = |project://series2/output/type1_clones.json|;
    writeCloneReportToJson(type1, stats, outFile);
    println("Wrote Type 1 clone report (stats + classes) to <outFile>");


    return 0;
}


