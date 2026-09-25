Class IOC.API.Task Extends %RegisteredObject
{

/// GET /api/ioc/tasks — the task list with the enable/disable state taken from
/// the task object itself: the management API's own Suspended field does not
/// change when a task is enabled or disabled.
ClassMethod List() As %DynamicAbstractObject
{
    Set tList = ##class(IOC.Service.Management).CallAdmin("task/")
    Set tIter = tList.%GetIterator()
    While tIter.%GetNext(.tKey, .tTask) {
        Set tRecord = ##class(%SYS.Task).%OpenId(tTask.%Get("Id"))
        If $ISOBJECT(tRecord) {
            Do tTask.%Set("Suspended", +tRecord.Suspended, "boolean")
        }
    }
    Quit tList
}

/// GET /api/ioc/tasks/history — recent task runs, with their result status.
ClassMethod History() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("task/history/")
}

/// GET /api/ioc/tasks/history/:id — the runs of one task.
ClassMethod HistoryFor(pId As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.taskId = pId
    Quit ##class(IOC.Service.Management).CallAdmin("task/history/", "GET", tParams)
}

/// GET /api/ioc/tasks/detail/:id — the full task definition.
ClassMethod Get(pId As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.id = pId
    Quit ##class(IOC.Service.Management).CallAdmin("task", "GET", tParams)
}

/// GET /api/ioc/tasks/info/:id — schedule and last-run summary.
ClassMethod Info(pId As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.id = pId
    Quit ##class(IOC.Service.Management).CallAdmin("task/info", "GET", tParams)
}

/// GET /api/ioc/tasks/manager — the task manager's own state.
ClassMethod Manager() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("task/manager")
}

/// POST /api/ioc/tasks/run/:id — run the task now.
ClassMethod Run(pId As %String) As %DynamicAbstractObject
{
    Quit ..Action("task/run", pId)
}

/// POST /api/ioc/tasks/:id/enable or /disable.
///
/// The management API has no route that enables or disables a single task, so
/// this is the one task operation not built on it: the task object itself is
/// updated. It runs as the caller, so the caller needs write access to the
/// task's database.
ClassMethod SetSuspended(pId As %String, pSuspended As %Boolean) As %DynamicObject
{
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$ISOBJECT(tTask) {
        Throw ##class(%Exception.General).%New("TASK_NOT_FOUND", 50, "", "Task " _ pId _ " does not exist")
    }
    Set tTask.Suspended = pSuspended
    Set tSC = tTask.%Save()
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    }
    Set tResult = {}
    Do tResult.%Set("id", pId)
    Do tResult.%Set("suspended", pSuspended, "boolean")
    Quit tResult
}

/// DELETE /api/ioc/tasks/:id
ClassMethod Remove(pId As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.id = pId
    Quit ##class(IOC.Service.Management).CallAdmin("task", "DELETE", tParams)
}

/// Task actions take the id as a query parameter and expect a JSON body.
ClassMethod Action(pPath As %String, pId As %String) As %DynamicAbstractObject [ Private ]
{
    Set tParams = {}
    Set tParams.id = pId
    Quit ##class(IOC.Service.Management).CallAdmin(pPath, "POST", tParams, "{}")
}

}
