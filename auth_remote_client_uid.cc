#ifndef _GNU_SOURCE
#define _GNU_SOURCE /* for struct ucred */
#endif

#include <mysql/plugin_auth.h>
#include <pwd.h>
#include <string.h>
#include <sys/socket.h>

#include "my_compiler.h"

#define TCPOLEN_EXP_TCPRIV_BASE 10
#define TCPOLEN_EXP_TCPRIV_BASE_ALIGNED 12

/*  ref: https://www.iana.org/assignments/tcp-parameters/tcp-parameters.xhtml */
#define TCPOPT_TCPRIV_MAGIC 0xF991

#define TCPOPT_NOP 1       /*  Padding */
#define TCPOPT_EOL 0       /*  End of options */
#define TCPOPT_MSS 2       /*  Segment size negotiating */
#define TCPOPT_WINDOW 3    /*  Window scaling */
#define TCPOPT_SACK_PERM 4 /*  SACK Permitted */
#define TCPOPT_SACK 5      /*  SACK Block */
#define TCPOPT_TIMESTAMP 8 /*  Better RTT estimations/PAWS */
#define TCPOPT_MD5SIG 19   /*  MD5 Signature (RFC2385) */
#define TCPOPT_FASTOPEN 34 /*  Fast open (RFC7413) */
#define TCPOPT_EXP 254     /*  Experimental */

#ifndef TCP_SAVE_SYN
#define TCP_SAVE_SYN 27
#endif

#ifndef TCP_SAVED_SYN
#define TCP_SAVED_SYN 28
#endif

typedef struct tcpriv_info_s {
  unsigned int uid;
  unsigned int magic;
  unsigned char kind;
  unsigned char len;
} tcpriv_info;

static int get_tcpriv_info(tcpriv_info *tinfo, unsigned char *syn)
{
  socklen_t syn_len = sizeof(syn);
  int status = CR_ERROR;

  for (int i = 0; i < syn_len; i++) {
    if (syn[i] == TCPOPT_EXP && syn[i + 1] == TCPOLEN_EXP_TCPRIV_BASE &&
        ntohl(*(unsigned int *)&syn[i + 1 + 1]) == TCPOPT_TCPRIV_MAGIC) {
      /* tcpriv options field structure
        kind[1] + length[1] + magic[4] + content[4] */
      tifno->kind = syn[i];
      tinfo->len = syn[i + 1];
      tinfo->magic = ntohl(*(unsigned int *)&syn[i + 1 + 1]);
      tinfo->uid = ntohl(*(unsigned int *)&syn[i + 1 + 4 + 1]);
      status = CR_OK;
      break;
    }
  }

  return status;
}

static int tcpriv_auth(MYSQL_PLUGIN_VIO *vio, MYSQL_SERVER_AUTH_INFO *info)
{
  unsigned char *pkt;
  MYSQL_PLUGIN_VIO_INFO vio_info;
  socklen_t cred_len = sizeof(cred);
  struct passwd pwd_buf, *pwd;
  char buf[1024];
  unsigned char syn[500];
  socklen_t syn_len = sizeof(syn);
  tcpriv_info tinfo;

  if (info->user_name == nullptr) {
    if (vio->read_packet(vio, &pkt) < 0)
      return CR_ERROR;
  }

  info->password_used = PASSWORD_USED_NO_MENTION;

  vio->info(vio, &vio_info);
  if (vio_info.protocol != MYSQL_PLUGIN_VIO_INFO::MYSQL_VIO_SOCKET)
    return CR_ERROR;

  // get passive syn headers
  if (getsockopt(vio_info.socket, IPPROTO_TCP, TCP_SAVED_SYN, syn, &syn_len))
    return CR_ERROR;

  /// tcpriv supports IPv4 only
  if (syn_len != 60 || syn[0] >> 4 != 0x4)
    return CR_ERROR;

  // get remote client uid
  if (get_tcpriv_info(&tinfo, syn))
    return CR_ERROR;

  // TODO: parse uid from database name and compare tinfo.uid with the uid

  return CR_OK;
}

static int generate_auth_string_hash(char *outbuf MY_ATTRIBUTE((unused)), unsigned int *buflen,
                                     const char *inbuf MY_ATTRIBUTE((unused)),
                                     unsigned int inbuflen MY_ATTRIBUTE((unused)))
{
  *buflen = 0;
  return 0;
}

static int validate_auth_string_hash(char *const inbuf MY_ATTRIBUTE((unused)),
                                     unsigned int buflen MY_ATTRIBUTE((unused)))
{
  return 0;
}

static int set_salt(const char *password MY_ATTRIBUTE((unused)), unsigned int password_len MY_ATTRIBUTE((unused)),
                    unsigned char *salt MY_ATTRIBUTE((unused)), unsigned char *salt_len)
{
  *salt_len = 0;
  return 0;
}

static struct st_mysql_auth tcpriv_auth_handler = {MYSQL_AUTHENTICATION_INTERFACE_VERSION,
                                                   nullptr,
                                                   tcpriv_auth,
                                                   generate_auth_string_hash,
                                                   validate_auth_string_hash,
                                                   set_salt,
                                                   AUTH_FLAG_PRIVILEGED_USER_FOR_PASSWORD_CHANGE,
                                                   nullptr};

mysql_declare_plugin(tcpriv_auth){
    MYSQL_AUTHENTICATION_PLUGIN,
    &tcpriv_auth_handler,
    "auth_tcpriv",
    PLUGIN_AUTHOR_ORACLE,
    "Unix Socket based authentication",
    PLUGIN_LICENSE_GPL,
    nullptr, /* Init */
    nullptr, /* Check uninstall */
    nullptr, /* Deinit */
    0x0101,
    nullptr,
    nullptr,
    nullptr,
    0,
} mysql_declare_plugin_end;
