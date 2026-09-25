Class IOC.Web.Application Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/health" Method="GET" Call="GetHealth" />
<Route Url="/system" Method="GET" Call="GetSystem" />
<Route Url="/system/usage" Method="GET" Call="GetSystemUsage" />
<Route Url="/system/license" Method="GET" Call="GetLicenseUsage" />
<Route Url="/system/processes" Method="GET" Call="GetProcesses" />
<Route Url="/system/processes/:pid" Method="DELETE" Call="DeleteProcess" />
<Route Url="/system/disk" Method="GET" Call="GetDiskUsage" />
<Route Url="/system/memory" Method="GET" Call="GetMemoryUsage" />
<Route Url="/system/devices" Method="GET" Call="GetDevices" />
<Route Url="/dashboard" Method="GET" Call="GetDashboard" />
<Route Url="/applications" Method="GET" Call="GetApplications" />
<Route Url="/applications/:app" Method="PUT" Call="PutApplication" />
<Route Url="/applications/detail/:app" Method="GET" Call="GetApplicationDetail" />
<Route Url="/applications/:app" Method="DELETE" Call="DeleteApplication" />
<Route Url="/tasks" Method="GET" Call="GetTasks" />
<Route Url="/tasks/history" Method="GET" Call="GetTaskHistory" />
<Route Url="/tasks/history/:id" Method="GET" Call="GetTaskHistoryFor" />
<Route Url="/tasks/manager" Method="GET" Call="GetTaskManager" />
<Route Url="/tasks/detail/:id" Method="GET" Call="GetTaskDetail" />
<Route Url="/tasks/info/:id" Method="GET" Call="GetTaskInfo" />
<Route Url="/tasks/run/:id" Method="POST" Call="RunTask" />
<Route Url="/tasks/:id/enable" Method="POST" Call="EnableTask" />
<Route Url="/tasks/:id/disable" Method="POST" Call="DisableTask" />
<Route Url="/tasks/:id" Method="DELETE" Call="DeleteTaskById" />
<Route Url="/users" Method="GET" Call="GetUsers" />
<Route Url="/security/users/:name" Method="GET" Call="GetUserDetail" />
<Route Url="/roles" Method="GET" Call="GetRoles" />
<Route Url="/security/roles/:name" Method="GET" Call="GetRoleDetail" />
<Route Url="/security/resources" Method="GET" Call="GetResources" />
<Route Url="/security/audit/records" Method="POST" Call="GetAuditRecords" />
<Route Url="/security/audit/enabled" Method="GET" Call="GetAuditEnabled" />
<Route Url="/security/oauth/clients" Method="GET" Call="GetOAuthClients" />
<Route Url="/security/oauth/server" Method="GET" Call="GetOAuthServer" />
<Route Url="/security/oauth/resource-servers" Method="GET" Call="GetOAuthResourceServers" />
<Route Url="/logs/intelligence" Method="GET" Call="GetLogIntelligence" />
<Route Url="/logs/audit" Method="POST" Call="GetAuditLog" />
<Route Url="/search/semantic" Method="POST" Call="SemanticSearch" />
<Route Url="/copilot/status" Method="GET" Call="GetCopilotStatus" />
<Route Url="/copilot/ask" Method="POST" Call="AskCopilot" />
<Route Url="/audit/events" Method="GET" Call="GetAuditEvents" />
<Route Url="/certificates" Method="GET" Call="GetCertificates" />
<Route Url="/wallets" Method="GET" Call="GetWallets" />
<Route Url="/secrets/:collection" Method="GET" Call="GetSecrets" />
<Route Url="/explorer/openapi/:ns/(.*)" Method="GET" Call="GetOpenApi" />
<Route Url="/explorer/send" Method="POST" Call="SendExplorerRequest" />
</Routes>
}

/// GET /api/ioc/health — liveness check.
ClassMethod GetHealth() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tData = {}
        Set tData.status = "ok"
        Do ..WriteSuccess(tData)
    } Catch ex {
        Set tSC = ex.AsStatus()
        Do ..WriteError("INTERNAL_ERROR", ex.DisplayString())
    }
    Quit tSC
}

/// GET /api/ioc/system
ClassMethod GetSystem() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetInfo())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/system/usage
ClassMethod GetSystemUsage() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetUsage())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// DELETE /api/ioc/system/processes/:pid
ClassMethod DeleteProcess(pPid As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).TerminateProcess(pPid))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pPid)
    }
    Quit $$$OK
}

/// GET /api/ioc/system/disk
ClassMethod GetDiskUsage() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetDiskUsage())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/system/memory
ClassMethod GetMemoryUsage() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetMemoryUsage())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/system/devices
ClassMethod GetDevices() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetDevices())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/system/license
ClassMethod GetLicenseUsage() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetLicenseUsage())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/system/processes
ClassMethod GetProcesses() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.System).GetProcesses())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/dashboard
ClassMethod GetDashboard() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Dashboard).GetMain())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/applications
ClassMethod GetApplications() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Application).List())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/applications/detail/:app
/// The path segment carries the application name with "/" replaced by "~",
/// because a name contains slashes and cannot be a single path segment.
ClassMethod GetApplicationDetail(pApp As %String) As %Status
{
    Set tApp = $REPLACE(pApp, "~", "/")
    Try {
        Do ..WriteSuccess(##class(IOC.API.Application).Get(tApp))
    } Catch ex {
        Do ..WriteErrorFromException(ex, tApp)
    }
    Quit $$$OK
}

/// PUT /api/ioc/applications/:app — body is the web application definition.
ClassMethod PutApplication(pApp As %String) As %Status
{
    Set tApp = $REPLACE(pApp, "~", "/")
    Try {
        Do ..WriteSuccess(##class(IOC.API.Application).Save(tApp, ..RequestBody()))
    } Catch ex {
        Do ..WriteErrorFromException(ex, tApp)
    }
    Quit $$$OK
}

/// DELETE /api/ioc/applications/:app
ClassMethod DeleteApplication(pApp As %String) As %Status
{
    Set tApp = $REPLACE(pApp, "~", "/")
    Try {
        Do ..WriteSuccess(##class(IOC.API.Application).Remove(tApp))
    } Catch ex {
        Do ..WriteErrorFromException(ex, tApp)
    }
    Quit $$$OK
}

/// GET /api/ioc/explorer/openapi/:ns/(.*)
ClassMethod GetOpenApi(pNamespace As %String, pApp As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Explorer).GetSpec(pNamespace, pApp))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pNamespace _ " " _ pApp)
    }
    Quit $$$OK
}

/// POST /api/ioc/explorer/send
ClassMethod SendExplorerRequest() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Explorer).Send(..RequestBody()))
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// Raw request body as a string, or "" when the request has none.
ClassMethod RequestBody() As %String [ Internal ]
{
    Set tContent = %request.Content
    If '$ISOBJECT(tContent) Quit $GET(tContent)
    Quit tContent.Read()
}

/// GET /api/ioc/tasks/history/:id
ClassMethod GetTaskHistoryFor(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).HistoryFor(pId))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// GET /api/ioc/tasks/manager
ClassMethod GetTaskManager() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).Manager())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/tasks/detail/:id
ClassMethod GetTaskDetail(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).Get(pId))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// GET /api/ioc/tasks/info/:id
ClassMethod GetTaskInfo(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).Info(pId))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// POST /api/ioc/tasks/run/:id
ClassMethod RunTask(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).Run(pId))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// POST /api/ioc/tasks/:id/enable
ClassMethod EnableTask(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).SetSuspended(pId, 0))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// POST /api/ioc/tasks/:id/disable
ClassMethod DisableTask(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).SetSuspended(pId, 1))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// DELETE /api/ioc/tasks/:id
ClassMethod DeleteTaskById(pId As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).Remove(pId))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pId)
    }
    Quit $$$OK
}

/// GET /api/ioc/tasks
ClassMethod GetTasks() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).List())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/users
ClassMethod GetUsers() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListUsers())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/roles
ClassMethod GetRoles() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListRoles())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/users/:name
ClassMethod GetUserDetail(pName As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).GetUser(pName))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pName)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/roles/:name
ClassMethod GetRoleDetail(pName As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).GetRole(pName))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pName)
    }
    Quit $$$OK
}

/// POST /api/ioc/security/audit/records
ClassMethod GetAuditRecords() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListAuditRecords(..RequestBody()))
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/audit/enabled
ClassMethod GetAuditEnabled() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).GetAuditEnabled())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/resources
ClassMethod GetResources() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListResources())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/oauth/clients
ClassMethod GetOAuthClients() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListOAuthClients())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/oauth/server
ClassMethod GetOAuthServer() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).GetOAuthServer())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// POST /api/ioc/search/semantic
ClassMethod SemanticSearch() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.SearchApi).Semantic(..RequestBody()))
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/copilot/status
ClassMethod GetCopilotStatus() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Copilot).Status())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// POST /api/ioc/copilot/ask
ClassMethod AskCopilot() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Copilot).Ask(..RequestBody()))
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/logs/intelligence
ClassMethod GetLogIntelligence() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Log).Intelligence())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// POST /api/ioc/logs/audit
ClassMethod GetAuditLog() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Log).GetAuditLog(..RequestBody()))
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/security/oauth/resource-servers
ClassMethod GetOAuthResourceServers() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListOAuthResourceServers())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/audit/events
ClassMethod GetAuditEvents() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListAuditEvents())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/tasks/history
ClassMethod GetTaskHistory() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Task).History())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/certificates
ClassMethod GetCertificates() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListCertificates())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/wallets
ClassMethod GetWallets() As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListWallets())
    } Catch ex {
        Do ..WriteErrorFromException(ex)
    }
    Quit $$$OK
}

/// GET /api/ioc/secrets/:collection
ClassMethod GetSecrets(pCollection As %String) As %Status
{
    Try {
        Do ..WriteSuccess(##class(IOC.API.Security).ListSecrets(pCollection))
    } Catch ex {
        Do ..WriteErrorFromException(ex, pCollection)
    }
    Quit $$$OK
}

/// Write a success envelope: { "success": true, "data": ..., "meta": {} }
ClassMethod WriteSuccess(pData As %DynamicAbstractObject) [ Internal ]
{
    Set tResp = {}
    Do tResp.%Set("success", 1, "boolean")
    Set tResp.data = pData
    Set tResp.meta = {}
    Do ..WriteJSON(tResp)
}

/// Map a caught exception onto the error envelope. Failures raised by the
/// management API adapter surface as 502 (upstream failure); anything else
/// is an internal error. pContext, when given, records the argument that was
/// passed in, which makes a bad lookup diagnosable from the response alone.
ClassMethod WriteErrorFromException(pEx As %Exception.AbstractException, pContext As %String = "") [ Internal ]
{
    ; DisplayString() renders "NAME code message"; %Exception.General carries the
    ; message on its own, so prefer that and keep the interface readable.
    Set tMessage = pEx.DisplayString()
    If $CLASSNAME(pEx) = "%Exception.General" {
        Set tData = ""
        Try {
            Set tData = pEx.Data
        } Catch {
            Set tData = ""
        }
        If tData '= "" Set tMessage = tData
    }
    If pContext '= "" Set tMessage = tMessage _ " [received: " _ pContext _ "]"
    If $CLASSNAME(pEx) = "%Exception.General" {
        Do ..WriteError("MANAGEMENT_API", tMessage, "502 Bad Gateway")
    } Else {
        Do ..WriteError("INTERNAL_ERROR", tMessage)
    }
}

/// Write an error envelope:
/// { "success": false, "error": { code, message, details } }
ClassMethod WriteError(pCode As %String, pMessage As %String, pHttpStatus As %String = "500 Internal Server Error") [ Internal ]
{
    Set %response.Status = pHttpStatus
    Set tResp = {}
    Do tResp.%Set("success", 0, "boolean")
    Set tErr = {}
    Set tErr.code = pCode
    Set tErr.message = pMessage
    Do tErr.%Set("details", "", "null")
    Set tResp.error = tErr
    Do ..WriteJSON(tResp)
}

/// Serialize a dynamic object to the response as application/json.
ClassMethod WriteJSON(pObj As %DynamicObject) [ Internal ]
{
    Set %response.ContentType = "application/json"
    Do pObj.%ToJSON()
}

}
