Class IOC.API.Dashboard Extends %RegisteredObject
{

/// GET /api/ioc/dashboard
ClassMethod GetMain() As %DynamicAbstractObject
{
    Quit ##class(IOC.Service.Management).CallAdmin("monitor/dashboard/main")
}

}
