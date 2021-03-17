package web

import (
	"context"

	"github.com/go-openapi/runtime/middleware"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/generated/openapi/models"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/log"
	"go.uber.org/zap"
)

type apiError interface {
	middleware.Responder
	SetStatusCode(int)
	SetPayload(error2 *models.Error)
}

func (a *apiImpl) handleError(ctx context.Context, err errors.Err, restErr apiError) middleware.Responder {
	codes := errorCodes(err.GetCode())
	if codes.httpCode/100 == 5 {
		log.Error(ctx, "internal error", zap.Error(err), zap.String("code", string(codes.stringCode)))
	}
	restErr.SetStatusCode(codes.httpCode)
	restErr.SetPayload(&models.Error{
		Code:    string(codes.stringCode),
		Message: err.GetMessage(),
	})
	return restErr
}

func errorCodes(err errors.Code) errCodesTuple {
	switch err {
	case errors.CodeUnauthenticated:
		return errCodesTuple{401, models.ErrorCodeUNAUTHENTICATED}
	case errors.CodeUnauthorized:
		return errCodesTuple{403, models.ErrorCodeUNAUTHORIZED}
	default:
		return errCodesTuple{500, models.ErrorCodeINTERNAL}
	}
}

type errCodesTuple struct {
	httpCode   int
	stringCode models.ErrorCode
}
