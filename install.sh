#/bin/bash

usage()
{
  cat <<EOF
Usage: $0 [options]

-h| --help		Show this help.
-A|--All		Execute all
-d|--dependencies	Insall dependencies. should be done after prerequisite
-p|--prerequisite	Install prerequisite. should be done before dependencies
-a|--ancible		Install the roles from roles.yml and execute playbook

EOF
}

install_prerequisite()
{
  sudopwd=$1

  echo "checking lsb_release existance"
  # is lsb_release installed
  if [ ! -x "$(command -v lsb_release)" ]; then
    echo "lsb-release is not installed"
    if [ -x "$(command -v apt-get)" ]; then
        echo -e "Oh we are on debian Familly\nInstalling lsb-release"
        echo "$sudopassword\n" | sudo -S -p '' apt-get install -y lsb-release
        pkg_manager="apt-get"
        init_pkg="lsb-release"
    elif [ -x "$(command -v yum)" ]; then
        echo "This is Red-Hat Family\nInstalling redhat-lsb"
        echo "$sudopassword\n" | sudo -S -p '' yum install -y redhat-lsb
        pkg_manager="yum"
        init_pkg="redhat-lsb"
    fi
    echo "installing $init_pkg with $pkg_manager :"
    echo "$sudopassword\n" | sudo -S -p '' $pkg_manager -y $init_pkg
  else
    echo "lsb_realease found ! :)"
  fi
  if [ ! -x "$(command -v lsb_release)" ]
  then
      echo "pb lsb_release not found"
      exit 202
  fi
}

install_dependencies()
{
  sudopwd=$1
  distId=`lsb_release -si`
  distRelease=`lsb_release -sr`
  distCodename=`lsb_release -sc`

  if [ "$distId" = 'Debian' -o "$distId" = 'Ubuntu' ]
  then
      pkgs_dep="build-essential libffi-dev libssl-dev python3 python3-dev python3-pip git"
      pip_pkgs="ansible jmespath"
  elif [ "$distId" = 'Red-Hat' -o "$distId" = 'CentOS'  ]
  then
      rh_build_essential="autoconf automake binutils autoconf automake binutils redhat-rpm-config rpm-build rpm-sign ctags elfutils indent patchutils"
      pkgs_dep="yum-utils openssl-devel libffi-devel python3 python3-devel python3-pip git $rh_build_essential"
      pip_pkgs="ansible jmespath"
  fi
  if [ ! -x "$(command -v pip3)" ]
  then
        echo "installing Python and build dependencies with $pkg_manager"
        echo "$sudopassword\n" | sudo -S -p '' $pkg_manager install -y -q $pkgs_dep
  fi
  if [ ! -x "$(command -v ansible)" ]
  then
        echo "installing $pip_pkgs through pip"
        echo "$sudopassword\n" | sudo -S -p '' pip3 install -q -U $pip_pkgs
  fi


}

execute_ansible()
{
  sudopwd=$1
  user=`whoami`
  
  echo "installing ansible galaxy roles"
  ansible-galaxy install -r roles.yml -p roles
  #to add remote user 
  #playbook_options="-u $user $@"
  # else
  #for a your secrets :
  if [ -f "vault/secrets.yml" ];then
      playbook_options="$playbook_options --ask-vault-pass"
  fi

  echo "running ansible playbook ..."
  echo "command : ansible-playbook main.yml --ask-become-pass --extra-vars \"account_default_user=$user\" $playbook_options"
  ansible-playbook main.yml --extra-vars "ansible_become_pass=$sudopassword account_default_user=$user" $playbook_options
}

execute_all()
{
  sudopwd=$1

  install_prerequisite $sudopwd

  install_dependencies $sudopwd

  execute_ansible $sudopwd
}

if [ $# -eq 0 ]
then
  usage
  exit 1
fi

echo -n  "type your SUDO Password: "
stty -echo
read sudopassword
stty echo
echo


case $1 in
  -A*) install_prerequisite $sudopassword
        if [ ! -x "$(command -v lsb_release)" ]
        then
            echo "pb lsb_release not found"
            exit 202
        fi
	install_dependencies $sudopassword
	execute_ansible $sudopassword
  	;;
  -p*) install_prerequisite $sudopassword
	;;
  -d*) install_dependencies $sudopassword
	;;
  -a*) execute_ansible $sudopassword
	;;
  *) usage
	exit 1
	;;
esac
