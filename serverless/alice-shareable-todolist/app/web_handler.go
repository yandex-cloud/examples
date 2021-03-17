// Copyright (c) 2021 Yandex LLC. All rights reserved.
// Author: Andrey Khaliullin <avhaliullin@yandex-team.ru>
// https://d5d5jb6msus0besv0ag0.apigw.yandexcloud.net

package main

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/auth"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/cloud"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/config"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/db"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/secure"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/todolist"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/web"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/web/apigw"
	webauth "github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/web/auth"
	ycsdk "github.com/yandex-cloud/go-sdk"
	"go.uber.org/zap"
)

type webApp struct {
	ctx             context.Context
	logger          *zap.Logger
	conf            *config.Config
	sdk             *ycsdk.SDK
	secureConfig    *secure.Config
	authService     auth.Service
	webAuthService  webauth.Service
	todoListService todolist.Service
	handler         *web.Handler
	repository      db.Repository
	txMgr           db.TxManager
}

func (w *webApp) GetLogger() *zap.Logger {
	assertInitialized(w.logger, "logger")
	return w.logger
}

func (w *webApp) GetContext() context.Context {
	assertInitialized(w.ctx, "ctx")
	return w.ctx
}

func (w *webApp) GetCloudSDK() *ycsdk.SDK {
	assertInitialized(w.sdk, "sdk")
	return w.sdk
}

func (w *webApp) GetSecureConfig() *secure.Config {
	assertInitialized(w.secureConfig, "secureConfig")
	return w.secureConfig
}

func (w *webApp) GetRepository() db.Repository {
	assertInitialized(w.repository, "repository")
	return w.repository
}

func (w *webApp) GetTxManager() db.TxManager {
	assertInitialized(w.txMgr, "txManager")
	return w.txMgr
}

func (w *webApp) GetAuthService() auth.Service {
	assertInitialized(w.authService, "authService")
	return w.authService
}

func (w *webApp) GetWebAuthService() webauth.Service {
	assertInitialized(w.webAuthService, "webAuthService")
	return w.webAuthService
}

func (w *webApp) GetTODOListService() todolist.Service {
	assertInitialized(w.todoListService, "todoListService")
	return w.todoListService
}

func (w *webApp) GetConfig() *config.Config {
	assertInitialized(w.conf, "conf")
	return w.conf
}

var webAppInstance *webApp

func initWebApp() (*webApp, error) {
	ctx, err := initLogging()
	if err != nil {
		return nil, err
	}
	log.Info(ctx, "initializing web app")

	webAppInstance = &webApp{ctx: ctx, conf: config.LoadFromEnv(), logger: log.FromCtx(ctx)}
	webAppInstance.sdk, err = cloud.NewSDK(webAppInstance)
	if err != nil {
		return nil, err
	}
	webAppInstance.secureConfig, err = secure.LoadConfig(webAppInstance)
	if err != nil {
		return nil, err
	}
	webAppInstance.repository, err = db.NewRepository()
	if err != nil {
		return nil, err
	}
	webAppInstance.txMgr, err = db.NewTxManager(webAppInstance)
	if err != nil {
		return nil, err
	}
	webAppInstance.authService, err = auth.NewService(webAppInstance)
	if err != nil {
		return nil, err
	}
	webAppInstance.webAuthService, err = webauth.NewService(webAppInstance)
	if err != nil {
		return nil, err
	}
	webAppInstance.todoListService, err = todolist.NewService(webAppInstance)
	if err != nil {
		return nil, err
	}
	webAppInstance.handler, err = web.NewHandler(webAppInstance)
	if err != nil {
		return nil, err
	}
	return webAppInstance, nil
}

func getWebApp() (*webApp, error) {
	if webAppInstance == nil {
		return initWebApp()
	}
	return webAppInstance, nil
}

func WebHandler(ctx context.Context, req *apigw.Request) (*apigw.Response, error) {
	webApp, err := getWebApp()
	if err != nil {
		return nil, err
	}
	return webApp.handler.Handle(ctx, req), nil
}
