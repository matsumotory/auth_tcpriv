# Pleas see the LICENSE file.

MYSQL_ADD_PLUGIN(auth_tcpriv
  auth_tcpriv.cc
  MODULE_ONLY
  MODULE_OUTPUT_NAME "auth_tcpriv"
  TEST_ONLY
  )

INSTALL(FILES
  auth_tcpriv.ini
  DESTINATION ${INSTALL_PLUGINDIR}
  COMPONENT Test
  )


