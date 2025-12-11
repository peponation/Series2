module clones::Type1

import lang::java::m3::AST;
import Node;
import List;
import Map;

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
