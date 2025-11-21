module Main

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import List;
import Set;
import String;
import Map;
import util::Math;

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

//returns a list of Type 1 clones found in the given ASTs
list[map[str, list[loc]]] Type1Clones(list[Declaration] asts, int minLines) {
    map[str, list[loc]] cloneMap = ();
    list[Stat] statements = [];

    for (ast <- asts) {
        //TODO: FIND STATEMENTS AND MATCH THEM TO S
        s = ast.body.declarations.methodDeclaration.body.statement*;
        statements += s;
    }
}

int main(int testArgument=0) {
    //asts = getASTs(|home:///Documents/School/Master/Software-Evolution/Series2/smallsql0.21_src|);
    //asts = getASTs(|home:///Documents/School/Master/Software-Evolution/Series2/hsqldb-2.3.1|);
    asts = getASTs(|home:///Documents/School/Master/Software-Evolution/Series2/CloneTesting|);
    int fileCount = size(asts);
    int ploc = countPhysicalLocFromAsts(asts);
    println("File count: <fileCount>");
    println("Physical LOC: <ploc>");
    return testArgument;
}

