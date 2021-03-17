package main

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice"
	aliceapi "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/api"
	aliceauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/alice/stateful"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/cloud"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/secure"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	ycsdk "github.com/yandex-cloud/go-sdk"
	"go.uber.org/zap"
)

type aliceApp struct {
	ctx              context.Context
	logger           *zap.Logger
	conf             *config.Config
	sdk              *ycsdk.SDK
	secureConfig     *secure.Config
	authService      auth.Service
	aliceAuthService aliceauth.Service
	todoListService  todolist.Service
	repository       db.Repository
	txMgr            db.TxManager
	handler          alice.Handler
}

func (a *aliceApp) GetLogger() *zap.Logger {
	assertInitialized(a.logger, "logger")
	return a.logger
}

func (a *aliceApp) GetContext() context.Context {
	assertInitialized(a.ctx, "ctx")
	return a.ctx
}

func (a *aliceApp) GetCloudSDK() *ycsdk.SDK {
	assertInitialized(a.sdk, "sdk")
	return a.sdk
}

func (a *aliceApp) GetSecureConfig() *secure.Config {
	assertInitialized(a.secureConfig, "secureConfig")
	return a.secureConfig
}

func (a *aliceApp) GetRepository() db.Repository {
	assertInitialized(a.repository, "repository")
	return a.repository
}

func (a *aliceApp) GetTxManager() db.TxManager {
	assertInitialized(a.txMgr, "txManager")
	return a.txMgr
}

func (a *aliceApp) GetAuthService() auth.Service {
	assertInitialized(a.authService, "authService")
	return a.authService
}

func (a *aliceApp) GetAliceAuthService() aliceauth.Service {
	assertInitialized(a.aliceAuthService, "aliceAuthService")
	return a.aliceAuthService
}

func (a *aliceApp) GetTODOListService() todolist.Service {
	assertInitialized(a.todoListService, "todoListService")
	return a.todoListService
}

func (a *aliceApp) GetConfig() *config.Config {
	assertInitialized(a.conf, "conf")
	return a.conf
}

var aliceAppInstance *aliceApp

func initAliceApp() (*aliceApp, error) {
	ctx, err := initLogging()
	if err != nil {
		return nil, err
	}
	log.Info(ctx, "initializing alice app")

	aliceAppInstance = &aliceApp{ctx: ctx, conf: config.LoadFromEnv(), logger: log.FromCtx(ctx)}
	aliceAppInstance.sdk, err = cloud.NewSDK(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	aliceAppInstance.secureConfig, err = secure.LoadConfig(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	aliceAppInstance.repository, err = db.NewRepository()
	if err != nil {
		return nil, err
	}
	aliceAppInstance.txMgr, err = db.NewTxManager(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	aliceAppInstance.authService, err = auth.NewService(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	aliceAppInstance.todoListService, err = todolist.NewService(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	aliceAppInstance.aliceAuthService, err = aliceauth.NewService(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	aliceAppInstance.handler, err = stateful.NewHandler(aliceAppInstance)
	//aliceAppInstance.handler, err = stateless.NewHandler(aliceAppInstance)
	if err != nil {
		return nil, err
	}
	return aliceAppInstance, nil
}

func getAliceApp() (*aliceApp, error) {
	if aliceAppInstance == nil {
		return initAliceApp()
	}
	return aliceAppInstance, nil
}

func AliceHandler(ctx context.Context, req *aliceapi.Request) (*aliceapi.Response, error) {
	aliceApp, err := getAliceApp()
	if err != nil {
		return nil, err
	}
	return aliceApp.handler.Handle(ctx, req)
}
