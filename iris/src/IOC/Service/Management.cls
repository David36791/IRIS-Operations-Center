Class IOC.Service.Management Extends %RegisteredObject
{

/// Location of the IRIS SysAdmin management API this adapter reuses.
Parameter AdminPath = "/api/admin/v1";

/// Location of the IRIS REST-application management API (OpenAPI specs, list).
Parameter MgmntPath = "/api/mgmnt";

/// Location of this instance's system metrics, which answer in Prometheus text.
Parameter MonitorPath = "/api/monitor";

/// Private web server port of this instance.
Parameter WebPort = 52773;

ClassMethod GetInstanceInfo() As %DynamicObject
{
    Set tInfo = {}
    Set tInfo.version = $ZVERSION
    Set tInfo.instanceName = ##class(%SYS.System).GetInstanceName()
    Set tInfo.namespace = $NAMESPACE
    Set tInfo.username = $USERNAME
    Set tInfo.roles = $ROLES
    Set tInfo.serverTime = $ZDT($HOROLOG, 3, 1)
    Quit tInfo
}

/// Call the SysAdmin management API (/api/admin/v1).
ClassMethod CallAdmin(pPath As %String, pMethod As %String = "GET", pParams As %DynamicObject = "", pBody As %String = "") As %DynamicAbstractObject
{
    Quit ..Call(..#AdminPath, pPath, pMethod, pParams, pBody)
}

/// Call the REST-application management API (/api/mgmnt).
ClassMethod CallMgmnt(pPath As %String, pMethod As %String = "GET", pParams As %DynamicObject = "", pBody As %String = "") As %DynamicAbstractObject
{
    Quit ..Call(..#MgmntPath, pPath, pMethod, pParams, pBody)
}

/// Fetch the instance's system metrics as text.
///
/// These answer in the Prometheus exposition format rather than the JSON
/// envelope the management APIs use, so they need their own path through the
/// adapter. The endpoint is unauthenticated in IRIS's own configuration, so no
/// credentials are forwarded.
ClassMethod CallMetrics() As %String
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "127.0.0.1"
    Set tReq.Port = ..#WebPort
    Set tReq.Location = ..#MonitorPath _ "/metrics"

    Set tSC = tReq.Get("")
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    }

    Set tResp = tReq.HttpResponse
    If '$ISOBJECT(tResp) {
        Throw ##class(%Exception.General).%New("SYSTEM_METRICS", 50, "", "No response from the system metrics endpoint")
    }
    If (tResp.StatusCode < 200) || (tResp.StatusCode > 299) {
        Throw ##class(%Exception.General).%New("SYSTEM_METRICS", 50, "", "System metrics endpoint returned HTTP " _ tResp.StatusCode)
    }
    Quit ..ReadBody(tResp.Data)
}

/// Adapter over IRIS's own management APIs.
///
/// Those APIs are the system's management surface, so they are reused rather
/// than reimplemented. The caller's credentials are forwarded, so the call
/// runs with exactly the caller's permissions.
///
/// Query parameters must go through SetParam: a query string appended to
/// Location is not sent as a query, it is treated as part of the path.
ClassMethod Call(pBase As %String, pPath As %String, pMethod As %String = "GET", pParams As %DynamicObject = "", pBody As %String = "") As %DynamicAbstractObject
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "127.0.0.1"
    Set tReq.Port = ..#WebPort
    Set tReq.Location = pBase _ "/" _ pPath

    Set tAuth = %request.GetCgiEnv("HTTP_AUTHORIZATION")
    If tAuth = "" Set tAuth = %request.GetCgiEnv("Authorization")
    If tAuth '= "" Do tReq.SetHeader("Authorization", tAuth)

    If $ISOBJECT(pParams) {
        Set tIter = pParams.%GetIterator()
        While tIter.%GetNext(.tKey, .tValue) {
            Do tReq.SetParam(tKey, tValue)
        }
    }
    If pBody '= "" {
        Set tBody = ##class(%GlobalCharacterStream).%New()
        Do tBody.Write(pBody)
        Set tReq.EntityBody = tBody
        ; Assigning the body resets the entity Content-Type to its default, so
        ; the type has to be (re)applied after the body is in place.
        Set tReq.ContentType = "application/json"
        Do tReq.SetHeader("Content-Type", "application/json")
    }

    ; Location is passed explicitly because Delete(location) has no default.
    Set tSC = $$$OK
    If pMethod = "POST" {
        Set tSC = tReq.Post("")
    } ElseIf pMethod = "PUT" {
        Set tSC = tReq.Put("")
    } ElseIf pMethod = "DELETE" {
        Set tSC = tReq.Delete("")
    } Else {
        Set tSC = tReq.Get("")
    }
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    }

    Set tResp = tReq.HttpResponse
    If '$ISOBJECT(tResp) {
        Throw ##class(%Exception.General).%New("MANAGEMENT_API", 50, "", "No response from the management API")
    }
    Set tBody = ..ReadBody(tResp.Data)

    ; An unknown route answers with an empty body, so check the status before
    ; attempting to parse, otherwise the failure is reported as a JSON error.
    If (tResp.StatusCode < 200) || (tResp.StatusCode > 299) {
        ; The body usually explains why ("OAuth 2.0 server is not configured"),
        ; so prefer that over dumping the raw response into the message.
        Set tDetail = ""
        Try {
            Set tParsed = {}.%FromJSON(tBody)
            Set tDetail = ..ErrorSummary(tParsed)
            If tDetail = "" Set tDetail = tParsed.%Get("msg")
        } Catch {
            Set tDetail = ""
        }
        If tDetail = "" Set tDetail = $EXTRACT(tBody, 1, 300)
        Throw ##class(%Exception.General).%New("MANAGEMENT_API", 50, "", "Management API request failed (HTTP " _ tResp.StatusCode _ ")" _ $SELECT(tDetail = "": "", 1: ": " _ tDetail))
    }

    ; Action endpoints (task run/suspend/resume) succeed with no payload.
    If tBody = "" Quit {}

    Set tPayload = ""
    Try {
        Set tPayload = {}.%FromJSON(tBody)
    } Catch {
        Throw ##class(%Exception.General).%New("MANAGEMENT_API", 50, "", "Management API returned a non-JSON response")
    }

    ; The SysAdmin API wraps its payload in {status,console,result} and reports
    ; failures inside that status block. The REST-application API (/api/mgmnt)
    ; answers with the payload itself and reports failures as {msg}.
    Set tMsg = tPayload.%Get("msg")
    If tMsg '= "" {
        Throw ##class(%Exception.General).%New("MANAGEMENT_API", 50, "", tMsg)
    }
    Set tSummary = ..ErrorSummary(tPayload)
    If tSummary '= "" {
        Throw ##class(%Exception.General).%New("MANAGEMENT_API", 50, "", tSummary)
    }
    If tPayload.%IsDefined("result") {
        Quit tPayload.%Get("result")
    }
    Quit tPayload
}

/// Read a response stream in full — Read() on its own stops at 32k.
ClassMethod ReadBody(pStream As %Stream.Object) As %String [ Private ]
{
    Set tBody = ""
    While 'pStream.AtEnd {
        Set tBody = tBody _ pStream.Read(32000)
    }
    Quit tBody
}

/// Execute a request against this instance's own web server, for the REST API
/// Explorer. The target host is fixed to the local instance, so this cannot be
/// used to reach anything else; credentials are forwarded so the call runs
/// with the caller's own permissions.
ClassMethod Proxy(pPath As %String, pMethod As %String = "GET", pParams As %DynamicObject = "", pHeaders As %DynamicObject = "", pBody As %String = "") As %DynamicObject
{
    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = "127.0.0.1"
    Set tReq.Port = ..#WebPort
    Set tReq.Location = pPath

    Set tAuth = %request.GetCgiEnv("HTTP_AUTHORIZATION")
    If tAuth = "" Set tAuth = %request.GetCgiEnv("Authorization")
    If tAuth '= "" Do tReq.SetHeader("Authorization", tAuth)

    If $ISOBJECT(pParams) {
        Set tIter = pParams.%GetIterator()
        While tIter.%GetNext(.tKey, .tValue) {
            Do tReq.SetParam(tKey, tValue)
        }
    }
    If $ISOBJECT(pHeaders) {
        Set tIter = pHeaders.%GetIterator()
        While tIter.%GetNext(.tKey, .tValue) {
            Do tReq.SetHeader(tKey, tValue)
        }
    }
    If pBody '= "" {
        Set tStream = ##class(%GlobalCharacterStream).%New()
        Do tStream.Write(pBody)
        Set tReq.EntityBody = tStream
        ; Assigning the body resets the entity Content-Type, so re-apply it.
        Set tReq.ContentType = "application/json"
        Do tReq.SetHeader("Content-Type", "application/json")
    }

    Set tStart = $PIECE($ZTIMESTAMP, ",", 2)
    Set tSC = $$$OK
    If pMethod = "POST" {
        Set tSC = tReq.Post("")
    } ElseIf pMethod = "PUT" {
        Set tSC = tReq.Put("")
    } ElseIf pMethod = "DELETE" {
        Set tSC = tReq.Delete("")
    } Else {
        Set tSC = tReq.Get("")
    }
    Set tElapsed = $PIECE($ZTIMESTAMP, ",", 2) - tStart
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    }

    Set tResp = tReq.HttpResponse
    If '$ISOBJECT(tResp) {
        Throw ##class(%Exception.General).%New("EXPLORER", 50, "", "No response from " _ pPath)
    }

    Set tResult = {}
    Set tResult.status = tResp.StatusCode
    Set tResult.durationMs = (tElapsed * 1000) \ 1
    Set tResult.contentType = tResp.ContentType
    Set tResult.headers = ..ResponseHeaders(tResp)
    Set tResult.body = ..ReadBody(tResp.Data)
    Quit tResult
}

/// Response headers as an object, from the fields the response exposes
/// directly. The full header collection is deliberately not walked here.
ClassMethod ResponseHeaders(pResp) [ Private ]
{
    Set tHeaders = {}
    Do tHeaders.%Set("Status-Line", pResp.StatusLine)
    Do tHeaders.%Set("Content-Type", pResp.ContentType)
    Do tHeaders.%Set("Content-Length", pResp.ContentLength)
    Quit tHeaders
}

/// Join the messages in a management API "status" block, or "" if there are none.
ClassMethod ErrorSummary(pPayload As %DynamicObject) As %String [ Private ]
{
    Set tStatus = pPayload.%Get("status")
    If '$ISOBJECT(tStatus) Quit ""
    Set tText = ""
    Set tErrors = tStatus.%Get("errors")
    If $ISOBJECT(tErrors) {
        Set tIter = tErrors.%GetIterator()
        While tIter.%GetNext(.tKey, .tErr) {
            Set tMsg = tErr.%Get("message")
            If tMsg = "" Set tMsg = tErr.%Get("error")
            If tMsg '= "" Set tText = tText _ $SELECT(tText = "": "", 1: "; ") _ tMsg
        }
    }
    If tText = "" Set tText = tStatus.%Get("summary")
    Quit tText
}

}
