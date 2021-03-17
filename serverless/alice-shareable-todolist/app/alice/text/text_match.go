package text

import (
	"unicode"

	"github.com/texttheater/golang-levenshtein/levenshtein"
	"github.com/yandex-cloud/examples/serverless/alice-shareable-todolist/app/model"
)

var levensteinOpts = levenshtein.Options{
	InsCost: 1,
	DelCost: 1,
	SubCost: 1,
	Matches: func(r rune, r2 rune) bool {
		return unicode.ToLower(r) == unicode.ToLower(r2)
	},
}

type options struct {
	minRatio float64
	prefix   string
}

type MatchCandidates interface {
	Len() int
	TextOf(idx int) string
}

func BestMatch(text string, candidates MatchCandidates, opts ...MatchOpt) (int, bool) {
	options := options{minRatio: 0.7}
	for _, opt := range opts {
		opt(&options)
	}
	n := candidates.Len()
	if n == 0 {
		return -1, false
	}
	bestRatio := 0.0
	bestMatchIdx := -1

	matchText := func(idx int, text string, candidate string) {
		ratio := levenshtein.RatioForStrings([]rune(text), []rune(candidate), levensteinOpts)
		if ratio > bestRatio {
			bestRatio = ratio
			bestMatchIdx = idx
		}
	}
	for idx := 0; idx < n; idx++ {
		candidateText := candidates.TextOf(idx)
		matchText(idx, text, candidateText)
		if options.prefix != "" {
			matchText(idx, options.prefix+" "+text, candidateText)
			matchText(idx, text, options.prefix+" "+candidateText)
		}
	}
	if bestRatio < options.minRatio {
		return -1, false
	}
	return bestMatchIdx, true
}

type MatchOpt func(*options)

func MatchMinRatio(r float64) MatchOpt {
	return func(o *options) {
		o.minRatio = r
	}
}

func MatchOptPrefix(prefix string) MatchOpt {
	return func(o *options) {
		o.prefix = prefix
	}
}

type ACLMatcher []*model.ACLEntry

func (o ACLMatcher) Len() int {
	return len(o)
}

func (o ACLMatcher) TextOf(idx int) string {
	return o[idx].Alias
}

type ListItemsMatcher []*model.ListItem

func (o ListItemsMatcher) Len() int {
	return len(o)
}

func (o ListItemsMatcher) TextOf(idx int) string {
	return o[idx].Text
}
