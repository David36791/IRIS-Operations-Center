Class IOC.API.SearchApi Extends %RegisteredObject
{

/// POST /api/ioc/search/semantic — body { "query": "..." }.
///
/// Semantic log search: the query and the candidate events are embedded with
/// the configured endpoint and ranked by cosine similarity (computed in
/// Embedded Python). Without a configured endpoint this reports why, rather
/// than falling back to a keyword match and calling it semantic.
ClassMethod Semantic(pBody As %String) As %DynamicAbstractObject
{
    Set tQuery = {}.%FromJSON(pBody).%Get("query")
    If tQuery = "" {
        Throw ##class(%Exception.General).%New("SEMANTIC", 50, "", "A query is required")
    }

    Set tRuns = ##class(IOC.Service.Management).CallAdmin("task/history/")
    Set tQueryVector = ##class(IOC.API.Copilot).Embed(tQuery)

    Set tScored = []
    Set tLimit = 30
    For tIndex = 0:1:tRuns.%Size()-1 {
        Quit:tIndex >= tLimit
        Set tRun = tRuns.%Get(tIndex)
        Set tText = (tRun.%Get("Name") _ " " _ tRun.%Get("Result")) _ " " _ tRun.%Get("Namespace")
        Set tVector = ##class(IOC.API.Copilot).Embed(tText)
        Set tScore = +##class(IOC.Service.LogIntelligence).Similarity(tQueryVector.%ToJSON(), tVector.%ToJSON())
        Do tScored.%Push({ "name": (tRun.%Get("Name")), "result": (tRun.%Get("Result")), "time": (tRun.%Get("Completed")), "score": (tScore) })
    }

    ; rank highest similarity first
    Set tSorted = []
    Set tRemaining = tScored.%Size()
    While tRemaining > 0 {
        Set tBest = -1, tBestScore = -2
        For tIndex = 0:1:tScored.%Size()-1 {
            Set tItem = tScored.%Get(tIndex)
            Continue:tItem.%Get("ranked")
            If +tItem.%Get("score") > tBestScore {
                Set tBestScore = +tItem.%Get("score")
                Set tBest = tIndex
            }
        }
        Quit:tBest < 0
        Set tItem = tScored.%Get(tBest)
        Do tItem.%Set("ranked", 1)
        Do tSorted.%Push(tItem)
        Set tRemaining = tRemaining - 1
    }

    Quit { "query": (tQuery), "matches": (tSorted) }
}

}
