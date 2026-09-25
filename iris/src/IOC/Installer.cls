Class IOC.Installer Extends %RegisteredObject
{

/// Create (or recreate) the web applications this project needs.
///
/// Both the Docker build and `zpm install` call this, so the two installation
/// paths share one definition. It is safe to run repeatedly: existing
/// definitions are removed first, because a web application cannot be created
/// twice.
///
/// Steps are guarded by a flag rather than an early Quit: inside a For loop
/// Quit only leaves the loop, so it cannot be used to abort the method.
///
/// Authentication note: the SPA shell is static and unauthenticated, while the
/// REST API requires password authentication. Anonymous access to a
/// dispatch-class application is not usable in this image — it is granted per
/// namespace database resource, and the anonymous user has no access to the
/// USER database — so dispatch applications in USER would answer 403.
///
/// InbndWebServicesEnabled must be 0: Create() defaults it to 1 here, and with
/// it enabled IRIS applies the inbound web service security context.
ClassMethod Setup() As %Status
{
    Set tSC = $$$OK
    Set tCaller = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tFailed = 0

        For tName = "/iris-operations/api/ioc", "/iris-operations" {
            If 'tFailed && ##class(Security.Applications).%ExistsId(tName) {
                Set tSC = ##class(Security.Applications).Delete(tName)
                If $$$ISERR(tSC) Set tFailed = 1
            }
        }

        ; --- REST API: /iris-operations/api/ioc -> IOC.Web.Application ---
        If 'tFailed {
            Kill props
            Set props("Name") = "/iris-operations/api/ioc"
            Set props("NameSpace") = "USER"
            Set props("DispatchClass") = "IOC.Web.Application"
            Set props("Description") = "IRIS Operations Center REST API"
            Set props("Enabled") = 1
            Set props("AutheEnabled") = 32
            Set props("InbndWebServicesEnabled") = 0
            Set props("Recurse") = 1
            Set tSC = ##class(Security.Applications).Create("/iris-operations/api/ioc", .props)
            If $$$ISERR(tSC) Set tFailed = 1
        }

        ; --- SPA shell: /iris-operations (static files) ---
        If 'tFailed {
            Kill props
            Set props("Name") = "/iris-operations"
            Set props("NameSpace") = "USER"
            Set props("Description") = "IRIS Operations Center SPA"
            Set props("Path") = "/usr/irissys/csp/iris-operations/"
            Set props("Enabled") = 1
            Set props("AutheEnabled") = 64
            Set props("InbndWebServicesEnabled") = 0
            Set props("RedirectEmptyPath") = 1
            Set tSC = ##class(Security.Applications).Create("/iris-operations", .props)
            If $$$ISERR(tSC) Set tFailed = 1
        }

        ; Create() does not reliably honour these props in every version, so
        ; set them explicitly afterwards.
        For tName = "/iris-operations/api/ioc", "/iris-operations" {
            If 'tFailed {
                Set tApp = ##class(Security.Applications).%OpenId(tName)
                Set tApp.AutheEnabled = $SELECT(tName = "/iris-operations/api/ioc": 32, 1: 64)
                Set tApp.InbndWebServicesEnabled = 0
                If tName = "/iris-operations" Set tApp.RedirectEmptyPath = 1
                Set tSC = tApp.%Save()
                If $$$ISERR(tSC) Set tFailed = 1
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tCaller
    Quit tSC
}

}
