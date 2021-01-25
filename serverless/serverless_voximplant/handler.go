package main

import (
	"context"
	"fmt"
	"strings"
)

func Handler(ctx context.Context, request *GatewayRequest) (map[string]interface{}, error) {
	res, err := handleRequest(ctx, request)
	if err != nil {
		if userErr, ok := err.(*userError); ok {
			return map[string]interface{}{
				"statusCode": userErr.status,
				"body":       map[string]interface{}{"error": userErr.msg},
				"headers": map[string][]string{
					"Content-Type": {"application/json"},
				},
			}, nil
		}
		return nil, err
	}
	return map[string]interface{}{
		"statusCode": 200,
		"body":       res,
		"headers": map[string][]string{
			"Content-Type": {"application/json"},
		},
	}, nil
}

func handleRequest(ctx context.Context, request *GatewayRequest) (interface{}, error) {
	if request == nil {
		return nil, fmt.Errorf("nil request")
	}
	err := authorizeRequest(ctx, request)
	if err != nil {
		return nil, err
	}
	switch request.Path {
	case Specs:
		return listSpecs(ctx)
	case Places:
		return listPlaces(ctx)
	case Dates:
		return listDates(ctx, &datesRequest{
			Spec:  getParam(request, "specId"),
			Place: getParam(request, "placeId"),
		})
	case Doctors:
		return listDocs(ctx, &doctorsRequest{
			Spec:  getParam(request, "specId"),
			Place: getParam(request, "placeId"),
			Date:  getParam(request, "date"),
		})
	case Slots:
		return newSlots(ctx, &slotsRequest{
			ClientID:     getParam(request, "clientId"),
			Spec:         getParam(request, "specId"),
			Place:        getParam(request, "placeId"),
			Date:         getParam(request, "date"),
			Doctors:      getMultiparam(request, "doctor"),
			ExcludeSlots: getMultiparam(request, "excludeSlot"),
			CancelSlots:  getMultiparam(request, "cancelSlot"),
		})
	case AckSlot:
		return ackSlot(ctx, &ackSlotRequest{
			ClientID:    getParam(request, "clientId"),
			SlotID:      getParam(request, "slotId"),
			CancelSlots: getMultiparam(request, "cancelSlot"),
		})
	default:
		return map[string]interface{}{
			"context": ctx,
			"request": request,
		}, nil
	}
}

func getParam(r *GatewayRequest, name string) string {
	values := r.Params[name]
	if len(values) == 0 {
		return ""
	}
	return values[0]
}

func getMultiparam(r *GatewayRequest, name string) []string {
	var res []string
	for _, value := range r.Params[name] {
		if len(value) > 0 {
			res = append(res, value)
		}
	}
	return res
}

func authorizeRequest(ctx context.Context, r *GatewayRequest) error {
	authHeader := r.Headers["Authorization"]
	if len(authHeader) == 0 {
		return newErrorUnauthorized("missing Authorization header")
	}

	const oauthPrefix = "OAuth "
	if !strings.HasPrefix(authHeader, oauthPrefix) {
		return newErrorUnauthorized("only OAuth authentication supported")
	}
	token := authHeader[len(oauthPrefix):]
	if len(token) == 0 {
		return newErrorUnauthorized("empty OAuth token provided")
	}
	login, err := authenticateByToken(ctx, token)
	if err != nil {
		return err
	}
	return authorizeUser(ctx, login)
}

type GatewayRequest struct {
	Path    string              `json:"path"`
	Params  map[string][]string `json:"multiValueParams"`
	Headers map[string]string   `json:"headers"`
}
