Class IOC.API.Security Extends %RegisteredObject
{

/// GET /api/ioc/users
ClassMethod ListUsers() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/user/")
}

/// GET /api/ioc/security/users/:name — one user, including its roles.
ClassMethod GetUser(pName As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.name = ..Decode(pName)
    Quit ##class(IOC.Service.Management).CallAdmin("security/user", "GET", tParams)
}

/// GET /api/ioc/security/roles/:name — one role, including its resources.
ClassMethod GetRole(pName As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.name = ..Decode(pName)
    Quit ##class(IOC.Service.Management).CallAdmin("security/role", "GET", tParams)
}

/// POST /api/ioc/security/audit/records — audit records matching the filter
/// body the caller supplies.
ClassMethod ListAuditRecords(pBody As %String) As %DynamicAbstractObject
{
    If pBody = "" Set pBody = "{}"
    Quit ##class(IOC.Service.Management).CallAdmin("security/audit/record/", "POST", "", pBody)
}

/// GET /api/ioc/security/audit/enabled
ClassMethod GetAuditEnabled() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/audit/enabled", "GET")
}

/// GET /api/ioc/security/resources — every resource that can be granted.
ClassMethod ListResources() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/resource/")
}

/// GET /api/ioc/security/oauth/clients
ClassMethod ListOAuthClients() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/oauth2/client/server-definition/")
}

/// GET /api/ioc/security/oauth/server
ClassMethod GetOAuthServer() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/oauth2/server")
}

/// GET /api/ioc/security/oauth/resource-servers
ClassMethod ListOAuthResourceServers() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/oauth2/resource-server/")
}

/// A path segment arrives URL-encoded, so "%25" stands for a literal "%"
/// (role names such as %All start with one).
ClassMethod Decode(pValue As %String) As %String [ Private ]
{
    Quit $SELECT(pValue [ "%25": $ZCONVERT(pValue, "I", "URL"), 1: pValue)
}

/// GET /api/ioc/roles
ClassMethod ListRoles() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/role/")
}

/// GET /api/ioc/audit/events
ClassMethod ListAuditEvents() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/audit/event/")
}

/// GET /api/ioc/certificates — X.509 credentials.
ClassMethod ListCertificates() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("security/x509-credential/")
}

/// GET /api/ioc/wallets — wallet collections.
ClassMethod ListWallets() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("wallet/")
}

/// GET /api/ioc/secrets/:collection
ClassMethod ListSecrets(pCollection As %String = "") As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.collection = pCollection
    Quit ##class(IOC.Service.Management).CallAdmin("wallet/secret/", "GET", tParams)
}

}
