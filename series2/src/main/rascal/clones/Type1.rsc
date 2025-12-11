module clones::Type1

import lang::java::m3::AST;
import Node;
import List;
import Map;

// A simple representation of a clone class:
// each class has an id and a list of source locations for the cloned fragment.
data CloneClass = cloneClass(int id, list[loc] occurrences);

/**
 * Detect Type 1 clones in the given Java ASTs.
 *
 * Type 1 here means: identical AST subtrees after stripping locations.
 * We group nodes by their normalized AST structure and keep only buckets
 * that occur at least twice.
 *
 * @param asts      All compilation units of the project
 * @param minLines  Minimum number of source lines a fragment must cover
 */
public list[CloneClass] detectType1Clones(list[Declaration] asts, int minLines) {
    // key   = normalized AST of a subtree (as string)
    // value = list of source locations where that subtree occurs
    map[str, list[loc]] buckets = ();

    // Traverse every AST and look at all sub-nodes
    for (decl <- asts) {
        visit(decl) {
            case node n: {
                loc l = nodeSourceLocation(n);

                // Skip nodes that are not tied to source code
                if (l == |unknown:///|) {
                    continue;
                }

                int span = l.end.line - l.begin.line + 1;
                if (span < minLines) {
                    continue; // fragment too small
                }

                // Remove all annotations (locations, etc.) so only structure remains
                node normalized = unsetRec(n);
                str key = nodeKey(normalized);

                // Add this location to the corresponding bucket
                if (key in buckets) {
                    // Avoid storing the same location twice
                    if (l notin buckets[key]) {
                        buckets[key] = buckets[key] + [l];
                    }
                } else {
                    buckets[key] = [l];
                }
            }
        }
    }

    // Turn buckets into clone classes: we only keep keys with >= 2 occurrences
    list[CloneClass] result = [];
    int nextId = 1;

    for (str key <- buckets) {
        list[loc] occs = buckets[key];
        if (size(occs) >= 2) {
            result += cloneClass(nextId, occs);
            nextId += 1;
        }
    }

    return result;
}

/**
 * Extract the source location of any Java AST node we care about.
 * Falls back to |unknown:///| if the node has no source.
 */
loc nodeSourceLocation(node n) {
    loc l = |unknown:///|;

    if (Declaration d := n) {
        l = d.src;
    }
    if (Expression e := n) {
        l = e.src;
    }
    if (Statement s := n) {
        l = s.src;
    }

    return l;
}

/**
 * Turn a normalized AST node into a stable string key.
 * Using a single place for this makes it easy to change later
 * (e.g., if you want extra normalization).
 */
str nodeKey(node n) {
    return "<n>";
}
