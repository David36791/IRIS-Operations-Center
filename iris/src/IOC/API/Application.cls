Class IOC.API.Application Extends %RegisteredObject
{

/// GET /api/ioc/applications — the instance's web applications.
ClassMethod List() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("web-app/")
}

/// GET /api/ioc/applications/detail/:app
ClassMethod Get(pName As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.name = pName
    Quit ##class(IOC.Service.Management).CallAdmin("web-app", "GET", tParams)
}

/// PUT /api/ioc/applications/:app — create or update. The body is the web
/// application definition exactly as GET returns it, minus Name: the name
/// travels as a query parameter and the management API rejects a body that
/// repeats it. Fields left out of the body revert to their defaults, so an
/// edit must send back the whole definition.
ClassMethod Save(pName As %String, pBody As %String) As %DynamicAbstractObject
{
    Set tDefinition = {}.%FromJSON(pBody)
    Do tDefinition.%Remove("Name")
    Set tParams = {}
    Set tParams.name = pName
    Quit ##class(IOC.Service.Management).CallAdmin("web-app", "PUT", tParams, tDefinition.%ToJSON())
}

/// DELETE /api/ioc/applications/:app
ClassMethod Remove(pName As %String) As %DynamicAbstractObject
{
    Set tParams = {}
    Set tParams.name = pName
    Quit ##class(IOC.Service.Management).CallAdmin("web-app", "DELETE", tParams)
}

}
