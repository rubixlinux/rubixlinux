APPENDDEF(`confMAPDEF', `-DNEWDB -DSTARTTLS -DSASL=2 -DTCPWRAPPERS -DNIS -DMAP_REGEX -DSOCKETMAP')
APPENDDEF(`confLIBS', `-lnsl -lssl -lcrypto -lsasl2 -lwrap -lm -ldb -lresolv')
APPENDDEF(`conf_libmilter_ENVDEF', `-DMILTER')
APPENDDEF(`conf_sendmail_ENVDEF', `-DMILTER')
APPENDDEF(`conf_libmilter_ENVDEF', `-D_FFR_MILTER_ROOT_UNSAFE ')