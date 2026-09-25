Class IOC.API.Log Extends %RegisteredObject
{

/// GET /api/ioc/logs/intelligence — task-run activity grouped into patterns,
/// analysed with Embedded Python.
ClassMethod Intelligence() As %DynamicAbstractObject
{
    Set tRuns = ##class(IOC.Service.Management).CallAdmin("task/history/")
    Set tPatterns = ##class(IOC.Service.LogIntelligence).Analyse(tRuns.%ToJSON())
    Quit {}.%FromJSON(tPatterns)
}

/// POST /api/ioc/logs/audit — audit records, filtered by the caller's body.
ClassMethod GetAuditLog(pBody As %String) As %DynamicAbstractObject
{
    If pBody = "" Set pBody = "{}"
    Quit ##class(IOC.Service.Management).CallAdmin("security/audit/record/", "POST", "", pBody)
}

/// The instance's message log is not exposed here. IRIS blocks web
/// applications from reading arbitrary files, and it offers no API that reads
/// the log back, so the log centre is built from the sources that are
/// reachable: task runs and audit records.

}
