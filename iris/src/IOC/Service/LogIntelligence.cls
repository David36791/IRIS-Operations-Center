Class IOC.Service.LogIntelligence Extends %RegisteredObject
{

/// Group event records into patterns:
/// first seen, last seen, occurrence count, related services and severity.
///
/// This runs in Embedded Python because the analysis is genuinely data
/// shaping — grouping, ordering and aggregate statistics — rather than a
/// token call into the interpreter.
ClassMethod Analyse(pRunsJson As %String) As %String [ Language = python ]
{
    import json
    from collections import defaultdict

    runs = json.loads(pRunsJson)
    grouped = defaultdict(list)
    for run in runs:
        grouped[run.get("Name") or "task"].append(run)

    patterns = []
    for name, entries in grouped.items():
        stamps = sorted(
            (entry.get("Completed") or entry.get("LastStart") or "")
            for entry in entries
            if (entry.get("Completed") or entry.get("LastStart"))
        )
        failures = [
            entry for entry in entries
            if str(entry.get("Status")) != "1" or int(entry.get("ErrNumber") or 0) != 0
        ]
        services = sorted({entry.get("Namespace") or "" for entry in entries if entry.get("Namespace")})
        sample = failures[0] if failures else entries[0]

        patterns.append({
            "pattern": name,
            "firstSeen": stamps[0] if stamps else "",
            "lastSeen": stamps[-1] if stamps else "",
            "occurrences": len(entries),
            "failures": len(failures),
            "relatedServices": services,
            "severity": "ERROR" if failures else "SUCCESS",
            "message": sample.get("Result") or "",
        })

    patterns.sort(key=lambda item: (-item["failures"], -item["occurrences"], item["pattern"]))
    return json.dumps(patterns)
}

/// Cosine similarity between two equal-length vectors.
ClassMethod Similarity(pLeft As %String, pRight As %String) As %String [ Language = python ]
{
    import json
    import math

    left = json.loads(pLeft)
    right = json.loads(pRight)
    if not left or len(left) != len(right):
        return "0"
    dot = sum(a * b for a, b in zip(left, right))
    norm = math.sqrt(sum(a * a for a in left)) * math.sqrt(sum(b * b for b in right))
    return str(dot / norm) if norm else "0"
}

}
