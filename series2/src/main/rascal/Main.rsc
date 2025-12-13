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
    int minLines = 2;
    list[CloneClass] rawType1 = detectType1MethodClonesAst(asts, minLines);

    // Apply subsumption: remove classes strictly included in others
    list[CloneClass] type1 = removeSubsumedClasses(rawType1);

    println("AST-based Type 1 method clone classes after subsumption (\>= <minLines> lines): <size(type1)>");



    int limit = min(5, size(type1));
    for (CloneClass c <- type1[0..limit]) {
        println("Clone class <c.id> with <size(c.members)> occurrences:");
        for (loc l <- c.members) {
            println("  <l>");
        }
    }

    // --- Write JSON output to a directory ---
    // Make sure this directory exists in your project:
    //   series2/src/main/rascal/output/
    loc outFile = |project://series2/output/type1_clones.json|;
    writeType1ClonesToJson(type1, outFile);
    println("Wrote Type 1 clone classes to <outFile>");

    return 0;
}

