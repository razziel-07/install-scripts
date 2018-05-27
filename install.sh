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
  if [ ! -x "$(command -v lsb_release)" ]
  then
    echo "not found"
    #what's my package manager
    if [ -x "$(command -v apt-get)" ]
    then
        echo 'installing lsb release for Debian family (apt-get pkg manager)'
        echo "$sudopwd\n" | sudo -S -p '' apt-get install -y lsb-release
    # elif [ -x "$(command -v yum)" ]; then
    #    echo "$sudopwd\n" | sudo -S -p '' yum install -y redhat-lsb
    fi
  else
    echo "found ! :)"
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
      echo "checking pip installation"
      if [ ! -x "$(command -v pip)" ]
      then
          echo "pip not found :"
          echo "- installing Python and build dependencies ..."
          echo "$sudopwd\n" | sudo -S -p '' apt-get install -y -q build-essential libffi-dev libssl-dev python python-dev python-setuptools git
          echo "$sudopwd\n" | sudo -S -p '' easy_install -q pip
      fi
      if [ ! -x "$(command -v ansible)" ]
      then
	  echo "pip found :"
          echo "- installing Ansible ..."
          echo "$sudopwd\n" | sudo -S -p '' pip install -q -U ansible
      fi
  fi
}

execute_ansible()
{
  sudopwd=$1
  user=`whoami`

  echo "installing ansible galaxy roles"
  ansible-galaxy install -r roles.yml -p roles

  playbook_options="-u $user $@"

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
