## OpenLDAP

### 环境

+ `OS`: `CentOS 7.8`
+ `Docker`：`19.03.8`
+ `Docker Compose`：`1.26.0`

### 部署

+ 安装客户端：

```bash
yum install -y openldap-clients
```

+ 拷贝代码：

```bash
rsync -azPS --delete --exclude="*.git*" docker-openldap VPN:/root/
```

+ 构建镜像：

```bash
cd /root/docker-openldap
docker build --no-cache --tag docker-openldap .
```

+ 启动容器：

```bash
docker-compose up -d
```

+ 进入容器：

```bash
docker exec -it openldap bash
```

### 使用

+ 导入组织架构：

```bash
vim departments.ldif
```

```ini
dn: ou=R&D,ou=Users,dc=xiaocoder,dc=com
changetype: add
objectClass: organizationalUnit
ou: 研发部

dn: ou=CTO,ou=R&D,ou=Users,dc=xiaocoder,dc=com
changetype: add
objectClass: organizationalUnit
ou: CTO
```

```bash
ldapmodify -x -H ldap://127.0.0.1:389 -D 'cn=admin,dc=xiaocoder,dc=com' -w Xiao@2020# -f departments.ldif -c
```

+ 生成用户密码：

```bash
docker exec -it openldap slappasswd -o module-load=pw-pbkdf2.so -h {PBKDF2-SHA512} -s Xiao@2020
```

+ 导入员工信息：

```bash
vim users.ldif
```

```ini
dn: cn=wangyuxiao,ou=CTO,ou=R&D,ou=Users,dc=xiaocoder,dc=com
changetype: add
objectClass: inetOrgPerson
cn: wangyuxiao
sn: wangyuxiao
mail: 1026840746@qq.com
displayName: 王宇霄
userPassword: {PBKDF2-SHA512}10000$4312F.3qfYwPS/eY7y9sUA$kRN5LSUiwWSnhkzidKSpzpmaDE39Dt8biQ7/afSoGE.0JefksBDhDrQxvzAalYVd9U04GDdBAQiH6f5mdqDQWw
```

```bash
ldapmodify -x -H ldap://127.0.0.1:389 -D 'cn=admin,dc=xiaocoder,dc=com' -w Xiao@2020# -f users.ldif -c
```

+ 用户组：

```bash
vim groups.ldif
```

```ini
dn: ou=CTO,ou=Groups,dc=xiaocoder,dc=com
changetype: add
objectClass: groupOfUniqueNames
cn: CTO
uniqueMember: cn=wangyuxiao,ou=CTO,ou=R&D,ou=Users,dc=xiaocoder,dc=com
```

```bash
ldapadd -x -H ldap://127.0.0.1:389 -D 'cn=admin,dc=xiaocoder,dc=com' -w Xiao@2020# -f groups.ldif -c
```

+ 更换用户密码：

```bash
vim change-password.ldif
```

```ini
dn: cn=wangyuxiao,ou=CTO,ou=R&D,ou=Users,dc=xiaocoder,dc=com
changetype: modify
replace: userPassword
userPassword: {PBKDF2-SHA512}10000$4312F.3qfYwPS/eY7y9sUA$kRN5LSUiwWSnhkzidKSpzpmaDE39Dt8biQ7/afSoGE.0JefksBDhDrQxvzAalYVd9U04GDdBAQiH6f5mdqDQWw
```

```bash
ldapmodify -x -H ldap://127.0.0.1:389 -D 'cn=admin,dc=xiaocoder,dc=com' -w Xiao@2020# -f change-password.ldif -c
# 容器内部
ldapmodify -Y EXTERNAL -H ldapi://%2Frun%2Fopenldap%2Fldapi -f "change-password.ldif" -c
```

+ 删除指定条目的属性：

```bash
vim remove-attribute.ldif
```

```ini
# https://docs.oracle.com/cd/E19693-01/819-0995/bcacx/index.html
dn: cn=wangyuxiao,ou=CTO,ou=R&D,ou=Users,dc=xiaocoder,dc=com
changetype: modify
delete: departmentNumber
```

```bash
ldapmodify -x -H ldap://127.0.0.1:389 -D 'cn=admin,dc=xiaocoder,dc=com' -w Xiao@2020# -f remove-attribute.ldif -c
```

***
