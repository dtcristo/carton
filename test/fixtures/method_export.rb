def decorate(text, suffix: '!') = yield("#{text}#{suffix}")

HANDLER = ->(value) { value * 2 }
