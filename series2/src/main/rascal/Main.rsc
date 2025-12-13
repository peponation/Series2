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



int main() {
    asts = getASTs(|project://smallsql0.21_src/|);
    // asts = getASTs(|project://CloneTesting|);
    // astsTwo = getASTs(|project://hsqldb-2.3.1/|);

    int fileCount = size(asts);
    int ploc = countPhysicalLocFromAsts(asts);
    println("File count: <fileCount>");
    println("Physical LOC: <ploc>");

    // --- AST-based Type 1 clone detection ---
    int minLines = 2;
    list[CloneClass] rawType1 = detectType1MethodClonesAst(asts, minLines);
    list[CloneClass] type1 = removeSubsumedClasses(rawType1);
    println("AST-based Type 1 method clone classes after subsumption (\>= <minLines> lines): <size(type1)>");

    // Example clones (you already had this, keep it for 'example clones' requirement)
    int limit = min(5, size(type1));
    for (CloneClass c <- type1[0..limit]) {
        println("Clone class <c.id> with <size(c.members)> occurrences:");
        for (loc l <- c.members) {
            println("  <l>");
        }
    }

    // --- Statistics ---
    CloneStats stats = computeCloneStats(type1, ploc);
    printCloneStats(stats);

    // --- JSON output ---
    loc outFile = |project://series2/output/type1_clones.json|;
    writeType1ClonesToJson(type1, outFile);
    println("Wrote Type 1 clone classes to <outFile>");

    return 0;
}


