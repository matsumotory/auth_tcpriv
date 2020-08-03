# Pleas see the LICENSE file.

MYSQL_ADD_PLUGIN(auth_remote_client_uid
  auth_remote_client_uid.cc
  MODULE_ONLY
  MODULE_OUTPUT_NAME "auth_remote_client_uid"
  TEST_ONLY
  )

INSTALL(FILES
  auth_remote_client_uid.ini
  DESTINATION ${INSTALL_PLUGINDIR}
  COMPONENT Test
  )


