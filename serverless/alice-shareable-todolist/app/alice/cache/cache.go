package cache

import (
	"context"

	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/errors"
)

type Supplier = func() (interface{}, errors.Err)

func GetCachedForRequest(ctx context.Context, key interface{}, supplier Supplier) (interface{}, errors.Err) {
	ctxValue := ctx.Value(cacheCtxKey{})
	if ctxValue == nil {
		return supplier()
	}
	c := ctxValue.(*cache)
	return c.getCached(key, supplier)
}

func ContextWithCache(ctx context.Context) context.Context {
	return context.WithValue(ctx, cacheCtxKey{}, &cache{})
}

type cache struct {
	values map[interface{}]interface{}
}

func (c *cache) getCached(key interface{}, supplier Supplier) (interface{}, errors.Err) {
	if res, ok := c.values[key]; ok {
		return res, nil
	}
	res, err := supplier()
	if err != nil {
		return nil, err
	}
	if c.values == nil {
		c.values = make(map[interface{}]interface{})
	}
	c.values[key] = res
	return res, nil
}

type cacheCtxKey struct{}
