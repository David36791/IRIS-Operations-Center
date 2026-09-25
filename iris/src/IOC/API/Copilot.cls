Class IOC.API.Copilot Extends %RegisteredObject
{

/// GET /api/ioc/copilot/status — what the AI integration is configured to do.
ClassMethod Status() As %DynamicObject
{
    Set tOut = {}
    Set tEnabled = (..Env("IOC_AI_ENABLED") = "true")
    Set tBaseUrl = ..Env("IOC_AI_BASE_URL")
    Set tModel = ..Env("IOC_AI_MODEL")
    Do tOut.%Set("enabled", tEnabled, "boolean")
    Do tOut.%Set("configured", (tEnabled && (tBaseUrl '= "") && (tModel '= "")), "boolean")
    Do tOut.%Set("baseUrl", tBaseUrl)
    Do tOut.%Set("model", tModel)
    Do tOut.%Set("embeddingModel", ..EmbeddingModel())
    Do tOut.%Set("readOnly", 1, "boolean")
    Quit tOut
}

/// POST /api/ioc/copilot/ask — body { "prompt": "...", "context": { ... } }.
///
/// The copilot is read-only by design: it explains what the caller already
/// gathered and cannot run actions. Anything that changes the instance goes
/// through the normal page flow with its own confirmation.
ClassMethod Ask(pBody As %String) As %DynamicObject
{
    Set tRequest = {}.%FromJSON(pBody)
    Set tPrompt = tRequest.%Get("prompt")
    If tPrompt = "" {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "A prompt is required")
    }
    If ..Env("IOC_AI_ENABLED") '= "true" {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "AI is disabled. Set IOC_AI_ENABLED=true, IOC_AI_BASE_URL and IOC_AI_MODEL to enable it.")
    }

    Set tBaseUrl = ..Env("IOC_AI_BASE_URL")
    Set tModel = ..Env("IOC_AI_MODEL")
    If (tBaseUrl = "") || (tModel = "") {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "IOC_AI_BASE_URL and IOC_AI_MODEL must be set")
    }

    Set tServer = "", tPort = 0, tHttps = 0, tPath = ""
    Do ..SplitUrl(tBaseUrl, .tServer, .tPort, .tHttps, .tPath)

    Set tContext = tRequest.%Get("context")
    Set tUserText = tPrompt
    If $ISOBJECT(tContext) Set tUserText = tPrompt _ $CHAR(10) _ $CHAR(10) _ "Instance data:" _ $CHAR(10) _ tContext.%ToJSON()

    Set tPayload = {}
    Set tPayload.model = tModel
    Set tSystem = {}
    Set tSystem.role = "system"
    Set tSystem.content = ..SystemPrompt()
    Set tUser = {}
    Set tUser.role = "user"
    Set tUser.content = tUserText
    Do tPayload.%Set("messages", [tSystem, tUser])

    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = tServer
    Set tReq.Port = tPort
    Set tReq.Https = tHttps
    Set tReq.Location = tPath _ "/chat/completions"
    Set tApiKey = ..Env("IOC_AI_API_KEY")
    If tApiKey '= "" Do tReq.SetHeader("Authorization", "Bearer " _ tApiKey)
    Set tStream = ##class(%GlobalCharacterStream).%New()
    Do tStream.Write(tPayload.%ToJSON())
    Set tReq.EntityBody = tStream
    ; assigning the body resets the entity Content-Type, so re-apply it
    Set tReq.ContentType = "application/json"
    Do tReq.SetHeader("Content-Type", "application/json")

    Set tSC = tReq.Post("")
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)

    Set tResp = tReq.HttpResponse
    If '$ISOBJECT(tResp) {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "No response from the AI endpoint")
    }
    Set tRaw = tResp.Data.Read()
    If (tResp.StatusCode < 200) || (tResp.StatusCode > 299) {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "AI endpoint returned HTTP " _ tResp.StatusCode _ ": " _ $EXTRACT(tRaw, 1, 300))
    }

    Set tResult = {}
    Try {
        Set tParsed = {}.%FromJSON(tRaw)
        Set tChoices = tParsed.%Get("choices")
        Set tFirst = tChoices.%Get(0)
        Set tResult.answer = tFirst.%Get("message").%Get("content")
    } Catch {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "AI endpoint returned an unexpected payload")
    }
    Set tResult.model = tModel
    Quit tResult
}

/// Embed one piece of text with the configured endpoint. Shared with the
/// semantic search, which needs the same connection details.
ClassMethod Embed(pText As %String) As %DynamicArray
{
    If ..Env("IOC_AI_ENABLED") '= "true" {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "Embeddings need the AI endpoint: set IOC_AI_ENABLED=true, IOC_AI_BASE_URL and IOC_AI_MODEL.")
    }
    Set tBaseUrl = ..Env("IOC_AI_BASE_URL")
    ; the embeddings model usually differs from the chat model
    Set tModel = ..Env("IOC_AI_EMBEDDING_MODEL")
    If tModel = "" Set tModel = ..Env("IOC_AI_MODEL")
    If (tBaseUrl = "") || (tModel = "") {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "IOC_AI_BASE_URL and an embedding model must be set")
    }

    Set tServer = "", tPort = 0, tHttps = 0, tPath = ""
    Do ..SplitUrl(tBaseUrl, .tServer, .tPort, .tHttps, .tPath)

    Set tPayload = {}
    Set tPayload.model = tModel
    Set tPayload.input = pText

    Set tReq = ##class(%Net.HttpRequest).%New()
    Set tReq.Server = tServer
    Set tReq.Port = tPort
    Set tReq.Https = tHttps
    Set tReq.Location = tPath _ "/embeddings"
    Set tApiKey = ..Env("IOC_AI_API_KEY")
    If tApiKey '= "" Do tReq.SetHeader("Authorization", "Bearer " _ tApiKey)
    Set tStream = ##class(%GlobalCharacterStream).%New()
    Do tStream.Write(tPayload.%ToJSON())
    Set tReq.EntityBody = tStream
    Set tReq.ContentType = "application/json"
    Do tReq.SetHeader("Content-Type", "application/json")

    Set tSC = tReq.Post("")
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    Set tResp = tReq.HttpResponse
    If '$ISOBJECT(tResp) {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "No response from the embeddings endpoint")
    }
    Set tRaw = tResp.Data.Read()
    If (tResp.StatusCode < 200) || (tResp.StatusCode > 299) {
        Throw ##class(%Exception.General).%New("COPILOT", 50, "", "Embeddings endpoint returned HTTP " _ tResp.StatusCode)
    }
    Set tParsed = {}.%FromJSON(tRaw)
    Quit tParsed.%Get("data").%Get(0).%Get("embedding")
}

/// The model used for embeddings: IOC_AI_EMBEDDING_MODEL when set, otherwise
/// the chat model.
ClassMethod EmbeddingModel() As %String
{
    Set tModel = ..Env("IOC_AI_EMBEDDING_MODEL")
    If tModel = "" Set tModel = ..Env("IOC_AI_MODEL")
    Quit tModel
}

ClassMethod SystemPrompt() As %String [ Private ]
{
    Quit "You are the IRIS Operations Center copilot. Explain what the supplied instance data means. " _
        "You cannot perform actions: deleting, restarting, terminating processes, revealing secrets and " _
        "changing security are out of scope, and you must say so if asked."
}

ClassMethod Env(pName As %String) As %String [ Private ]
{
    Quit ##class(%SYSTEM.Util).GetEnviron(pName)
}

/// Split an OpenAI-compatible base URL into connection parts.
ClassMethod SplitUrl(pUrl As %String, ByRef pServer, ByRef pPort, ByRef pHttps, ByRef pPath) [ Private ]
{
    Set tRest = pUrl
    Set pHttps = 0
    If $EXTRACT(tRest, 1, 8) = "https://" {
        Set pHttps = 1
        Set tRest = $EXTRACT(tRest, 9, *)
    } ElseIf $EXTRACT(tRest, 1, 7) = "http://" {
        Set tRest = $EXTRACT(tRest, 8, *)
    }
    If tRest [ "/" {
        Set pServer = $PIECE(tRest, "/", 1)
        Set pPath = "/" _ $PIECE(tRest, "/", 2, *)
    } Else {
        Set pServer = tRest
        Set pPath = ""
    }
    Set pPort = $SELECT(pHttps: 443, 1: 80)
    If pServer [ ":" {
        Set pPort = +$PIECE(pServer, ":", 2)
        Set pServer = $PIECE(pServer, ":", 1)
    }
}

}
