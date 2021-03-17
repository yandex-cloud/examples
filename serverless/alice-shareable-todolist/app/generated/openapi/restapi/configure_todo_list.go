// This file is safe to edit. Once it exists it will not be overwritten

package restapi

import (
	"crypto/tls"
	"net/http"

	"github.com/go-openapi/errors"
	"github.com/go-openapi/runtime"
	"github.com/go-openapi/runtime/middleware"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/generated/openapi/restapi/operations"
)

//go:generate swagger generate server --target ../../openapi --name TodoList --spec ../../../../gateway/gen/swagger-filtered.json --principal interface{} --exclude-main

func configureFlags(api *operations.TodoListAPI) {
	// api.CommandLineOptionsGroups = []swag.CommandLineOptionsGroup{ ... }
}

func configureAPI(api *operations.TodoListAPI) http.Handler {
	// configure the api here
	api.ServeError = errors.ServeError

	// Set your custom logger if needed. Default one is log.Printf
	// Expected interface func(string, ...interface{})
	//
	// Example:
	// api.Logger = log.Printf

	api.UseSwaggerUI()
	// To continue using redoc as your UI, uncomment the following line
	// api.UseRedoc()

	api.JSONConsumer = runtime.JSONConsumer()

	api.JSONProducer = runtime.JSONProducer()

	if api.AcceptInvitationHandler == nil {
		api.AcceptInvitationHandler = operations.AcceptInvitationHandlerFunc(func(params operations.AcceptInvitationParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.AcceptInvitation has not yet been implemented")
		})
	}
	if api.AddItemHandler == nil {
		api.AddItemHandler = operations.AddItemHandlerFunc(func(params operations.AddItemParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.AddItem has not yet been implemented")
		})
	}
	if api.CreateListHandler == nil {
		api.CreateListHandler = operations.CreateListHandlerFunc(func(params operations.CreateListParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.CreateList has not yet been implemented")
		})
	}
	if api.DeleteItemHandler == nil {
		api.DeleteItemHandler = operations.DeleteItemHandlerFunc(func(params operations.DeleteItemParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.DeleteItem has not yet been implemented")
		})
	}
	if api.DeleteListHandler == nil {
		api.DeleteListHandler = operations.DeleteListHandlerFunc(func(params operations.DeleteListParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.DeleteList has not yet been implemented")
		})
	}
	if api.GetListHandler == nil {
		api.GetListHandler = operations.GetListHandlerFunc(func(params operations.GetListParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.GetList has not yet been implemented")
		})
	}
	if api.GetListUsersHandler == nil {
		api.GetListUsersHandler = operations.GetListUsersHandlerFunc(func(params operations.GetListUsersParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.GetListUsers has not yet been implemented")
		})
	}
	if api.InviteUserHandler == nil {
		api.InviteUserHandler = operations.InviteUserHandlerFunc(func(params operations.InviteUserParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.InviteUser has not yet been implemented")
		})
	}
	if api.ListListsHandler == nil {
		api.ListListsHandler = operations.ListListsHandlerFunc(func(params operations.ListListsParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.ListLists has not yet been implemented")
		})
	}
	if api.PageLoginHandler == nil {
		api.PageLoginHandler = operations.PageLoginHandlerFunc(func(params operations.PageLoginParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.PageLogin has not yet been implemented")
		})
	}
	if api.PageReceiveTokenHandler == nil {
		api.PageReceiveTokenHandler = operations.PageReceiveTokenHandlerFunc(func(params operations.PageReceiveTokenParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.PageReceiveToken has not yet been implemented")
		})
	}
	if api.RevokeInvitationHandler == nil {
		api.RevokeInvitationHandler = operations.RevokeInvitationHandlerFunc(func(params operations.RevokeInvitationParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.RevokeInvitation has not yet been implemented")
		})
	}
	if api.UserInfoHandler == nil {
		api.UserInfoHandler = operations.UserInfoHandlerFunc(func(params operations.UserInfoParams) middleware.Responder {
			return middleware.NotImplemented("operation operations.UserInfo has not yet been implemented")
		})
	}

	api.PreServerShutdown = func() {}

	api.ServerShutdown = func() {}

	return setupGlobalMiddleware(api.Serve(setupMiddlewares))
}

// The TLS configuration before HTTPS server starts.
func configureTLS(tlsConfig *tls.Config) {
	// Make all necessary changes to the TLS configuration here.
}

// As soon as server is initialized but not run yet, this function will be called.
// If you need to modify a config, store server instance to stop it individually later, this is the place.
// This function can be called multiple times, depending on the number of serving schemes.
// scheme value will be set accordingly: "http", "https" or "unix".
func configureServer(s *http.Server, scheme, addr string) {
}

// The middleware configuration is for the handler executors. These do not apply to the swagger.json document.
// The middleware executes after routing but before authentication, binding and validation.
func setupMiddlewares(handler http.Handler) http.Handler {
	return handler
}

// The middleware configuration happens before anything, this middleware also applies to serving the swagger.json document.
// So this is a good place to plug in a panic handling middleware, logging and metrics.
func setupGlobalMiddleware(handler http.Handler) http.Handler {
	return handler
}
