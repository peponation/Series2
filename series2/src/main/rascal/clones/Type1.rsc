module clones::Type1

import lang::java::m3::AST;
import Node;      // for unsetRec
import List;
import Map;
import IO;       // for println

// One candidate subtree for clone detection
data CloneNode = cloneNode(
    int id,        // unique id
    loc location,  // source location
    value tree,    // normalized AST subtree (locations stripped)
    int size       // number of AST nodes in this subtree
);

// One clone class: multiple occurrences of the same structure
data CloneClass = cloneClass(
    int id,
    list[loc] occurrences
);

// Default thresholds (you can tweak these)
public int defaultMinLines    = 3;   // minimum lines a fragment must span
public int defaultMinNodeSize = 5;   // minimum number of AST nodes in the subtree

/**
 * Top-level Type 1 detector.
 *
 * Type 1 = identical AST structure after removing locations.
 */
public list[CloneClass] detectType1Clones(
    list[Declaration] asts,
    int minLines    = defaultMinLines,
    int minNodeSize = defaultMinNodeSize
) {
    println("=== Type 1 clone detection ===");
    println("ASTs: <size(asts)>, minLines = <minLines>, minNodeSize = <minNodeSize>");

    // 1. Collect all AST nodes from all compilation units
    list[value] rawNodes = collectAllNodes(asts);
    println("Total AST nodes collected: <size(rawNodes)>");

    // 2. Turn them into CloneNode candidates (filter by size and line span)
    list[CloneNode] candidates = buildCandidates(rawNodes, minLines, minNodeSize);
    println("Candidates after filtering: <size(candidates)>");

    // 3. Pairwise comparison to group identical structures
    map[int, int] nodeToClass = ();   // nodeId -> classId
    int nextClassId = 1;

    int n = size(candidates);
    for (int i <- [0..n-1]) {
        CloneNode left = candidates[i];

        for (int j <- [0..i-1]) {
            CloneNode right = candidates[j];

            // Quick filter: different subtree sizes can never be structurally equal
            if (left.size != right.size) {
                continue;
            }

            // Type 1 condition: normalized AST subtrees are exactly equal
            if (left.tree != right.tree) {
                continue;
            }

            // We have a clone pair: assign them to the same clone class
            int classId = resolveClass(nodeToClass, left.id, right.id, nextClassId);
            if (classId == nextClassId) {
                nextClassId += 1;
            }

            nodeToClass[left.id]  = classId;
            nodeToClass[right.id] = classId;
        }
    }

    println("Node-\>class mappings: <size(nodeToClass)>");

    // 4. Group locations per class
    map[int, list[loc]] locsPerClass = ();
    map[int, CloneNode] byId = indexById(candidates);

    for (int nodeId <- nodeToClass) {
        int classId = nodeToClass[nodeId];
        loc l = byId[nodeId].location;

        if (classId in locsPerClass) {
            if (l notin locsPerClass[classId]) {
                locsPerClass[classId] = locsPerClass[classId] + [l];
            }
        } else {
            locsPerClass[classId] = [l];
        }
    }

    // 5. Convert to CloneClass list, keep only real clone classes (>=2 members)
    list[CloneClass] result = [];
    for (int classId <- locsPerClass) {
        list[loc] occs = locsPerClass[classId];
        if (size(occs) >= 2) {
            result += cloneClass(classId, occs);
        }
    }

    println("Final Type 1 clone classes: <size(result)>");
    return result;
}

/* ====================== helpers ====================== */

// Collect every AST node from all compilation units
list[value] collectAllNodes(list[Declaration] asts) {
    list[value] result = [];
    for (Declaration decl <- asts) {
        visit(decl) {
            case value v: result += v;
        }
    }
    return result;
}

// Build CloneNode candidates, filtering on line span and subtree size
list[CloneNode] buildCandidates(list[value] rawNodes, int minLines, int minNodeSize) {
    list[CloneNode] result = [];
    int nextId = 1;

    for (value v <- rawNodes) {
        loc l = valueSourceLocation(v);
        if (l == |unknown:///|) {
            continue;
        }

        int span = l.end.line - l.begin.line + 1;
        if (span < minLines) {
            continue;
        }

        // Remove all annotations (including locations) so only structure remains
        value normalized = unsetRec(v);

        int subtreeSz = subtreeSize(normalized);
        if (subtreeSz < minNodeSize) {
            continue;
        }

        result += cloneNode(nextId, l, normalized, subtreeSz);
        nextId += 1;
    }

    return result;
}

// Get source location for *any* Java AST node we care about
loc valueSourceLocation(value v) {
    loc l = |unknown:///|;

    if (Declaration d := v) {
        l = d.src;
    }
    if (Expression e := v) {
        l = e.src;
    }
    if (Statement s := v) {
        l = s.src;
    }

    return l;
}

// Count how many AST nodes are in this subtree
int subtreeSize(value v) {
    int count = 0;
    visit(v) {
        case value _: count += 1;
    }
    return count;
}

// Given a clone pair (leftId, rightId), decide which clone class they belong to
int resolveClass(map[int, int] nodeToClass, int leftId, int rightId, int nextClassId) {
    if (leftId in nodeToClass) {
        return nodeToClass[leftId];
    }
    if (rightId in nodeToClass) {
        return nodeToClass[rightId];
    }
    // neither node has a class yet → create a new one
    return nextClassId;
}

// Build an index from node id to the full CloneNode
map[int, CloneNode] indexById(list[CloneNode] nodes) {
    map[int, CloneNode] result = ();
    for (CloneNode cn <- nodes) {
        result[cn.id] = cn;
    }
    return result;
}
