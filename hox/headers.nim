import h2o
import macros

type
  HeaderReader* = object
    base*: ptr h2o.Headers

  HeaderWriter* = object
    base*: ptr h2o.Headers
    pool*: MemPoolPtr
    
macro defineHelper(token: TokenList): stmt =
  let base = ($token).substr(5)
  let setter = !(base & "=")
  let getter = !(base)
  result = quote do:
    proc `setter`*(self: HeaderWriter, val: string) {.inline.} =
      h2o_add_header(self.pool, self.base, tokenPtr(h2o.`token`), val, val.len)

    iterator `getter`*(self: HeaderReader): IOVec =
      let headers = self.base[]
      var cursor = -1

      while true:
        cursor = h2o_find_header(self.base, tokenPtr(h2o.`token`), cursor)
        if cursor == -1:
          break

        yield headers[cursor].value

    proc `getter`*(self: HeaderReader): IOVec {.inline.} =
      for val in self.`getter`:
        return val

defineHelper(TokenAccept)
defineHelper(TokenAcceptCharset)
defineHelper(TokenAcceptEncoding)
defineHelper(TokenAcceptLanguage)
defineHelper(TokenAcceptRanges)
defineHelper(TokenAccessControlAllowOrigin)
defineHelper(TokenAge)
defineHelper(TokenAllow)
defineHelper(TokenAuthorization)
defineHelper(TokenCacheControl)
defineHelper(TokenConnection)
defineHelper(TokenContentDisposition)
defineHelper(TokenContentEncoding)
defineHelper(TokenContentLanguage)
defineHelper(TokenContentLength)
defineHelper(TokenContentLocation)
defineHelper(TokenContentRange)
defineHelper(TokenContentType)
defineHelper(TokenCookie)
defineHelper(TokenDate)
defineHelper(TokenETag)
defineHelper(TokenExpect)
defineHelper(TokenExpires)
defineHelper(TokenHost)
defineHelper(TokenIfMatch)
defineHelper(TokenIfModifiedSince)
defineHelper(TokenIfNoneMatch)
defineHelper(TokenIfRange)
defineHelper(TokenIfUnmodifiedSince)
defineHelper(TokenLastModified)
defineHelper(TokenLink)
defineHelper(TokenLocation)
defineHelper(TokenMaxForwards)
defineHelper(TokenProxyAuthenticate)
defineHelper(TokenProxyAuthorization)
defineHelper(TokenRange)
defineHelper(TokenReferer)
defineHelper(TokenRefresh)
defineHelper(TokenRetryAfter)
defineHelper(TokenServer)
defineHelper(TokenSetCookie)
defineHelper(TokenStrictTransportSecurity)
defineHelper(TokenTransferEncoding)
defineHelper(TokenUpgrade)
defineHelper(TokenUserAgent)
defineHelper(TokenVary)
defineHelper(TokenVia)
defineHelper(TokenWWWAuthenticate)

