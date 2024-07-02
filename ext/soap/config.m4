PHP_ARG_ENABLE([soap],
  [whether to enable SOAP support],
  [AS_HELP_STRING([--enable-soap],
    [Enable SOAP support])])

if test "$PHP_SOAP" != "no"; then
  PHP_SETUP_LIBXML(SOAP_SHARED_LIBADD, [
    AC_DEFINE(HAVE_SOAP,1,[ ])
    PHP_NEW_EXTENSION(soap, soap.c php_encoding.c php_http.c php_packet_soap.c php_schema.c php_sdl.c php_xml.c, $ext_shared,, -DZEND_ENABLE_STATIC_TSRMLS_CACHE=1)
    PHP_SUBST([SOAP_SHARED_LIBADD])
  ])
  PHP_ADD_EXTENSION_DEP(soap, libxml)
  PHP_ADD_EXTENSION_DEP(soap, session, true)
fi
