#!/bin/bash

gcadmin="k8scadmin" ## cluster admin account(Full access everywhere)
gadmin="admin" ## full access to a specific namespace
guser="user" ## view only
grmgr="release-manager" ## view + delete pod permissions,!THIS IS CUSTOM ROLE,YOU HAVE TO CREATE IT IN YOUR CLUSTER!
gdplr="deployer" ## Can do deployments only, !THIS IS CUSTOM ROLE,YOU HAVE TO CREATE IT IN YOUR CLUSTER!

help(){
    echo "
    Description:

        With this program you can easily create user accounts to a kubernetes cluster.
        Pre-requests are:
         - kubectl tool installed with admin account configured.

        This tool does not create the cluster roles in the cluster,it assumes that
        they have already been created by admin.
        It currently uses 5 roles:
         - cluster-admin (Full access everywhere) [build-in]
         - admin (Namespace admin) [build-in]
         - user (Read only access) [build-in]
         - release-manager(Read only access,but can delete pods) [custom]
	 - deployer(Can do deployments, cicd oriented) [custom]
    
    Usage:

        Create a normal user named \"john\" to a namespace named \"doe\":
        - ${0} create john doe user 

        Create an admin user named \"john\" to a namespace named \"doe\":
        - ${0} create john doe admin
                
        Create a release-manager user named \"john\" to a namespace named \"doe\":
        - ${0} create john doe release-manager

        Create a deploy user name \"john\" to a namespace  named \"doe\":
        - ${0} create john doe deployer

        You can also create a user named \"john\" which has access to multiple namespaces passing
        the extra namespaces as arguments at the end.
        - ${0} create john namespace1 user namespace2 namespace3

        Create a cluster admin user named \"john\" namespace is not actualy used but needed to be there so \"doe\":
        - ${0} create john doe k8scadmin 

        To delete a user named \"john\" to a namespace named \"doe\":
        - ${0} delete john doe

        You can also create user config file for existing user \"john\" of namespace \"doe\" as:
        - ${0} config john doe"
    exit 127
}

create_user(){
    local user="${1}"
    local ns="${2}"
    kubectl create serviceaccount "${user}" -n "${ns}" 2>&1 >/dev/null
    return "${?}"
}

create_bind(){
    local user="${1}"
    local type="${2}"
    local std_ns="${3}"
    local extra_ns="${4}"

    if [[ ${extra_ns} == '' ]];then
        extra_ns=${std_ns}
    fi 
    if [[ "${type}" == "admin" ]];then
        role='edit'
    elif [[ "${type}" == "user" ]];then
        role='view'
    elif [[ "${type}" == "release-manager" ]];then
        role='release-managers'
    elif [[ "${type}" == "deployer" ]];then
	    role='deployer'
    elif [[ "${type}" == "k8scadmin" ]];then
	    role='cluster-admin'
    fi

    if [[ "${type}" == "k8scadmin" ]];then
        kubectl create clusterrolebinding "${user}" --clusterrole="${role}" --serviceaccount="${std_ns}":"${user}" 2>&1 >/dev/null 
        return "${?}"
    else
        kubectl create rolebinding "${user}" --clusterrole="${role}" --serviceaccount="${std_ns}":"${user}" --namespace="${extra_ns}" 2>&1 >/dev/null     
        return "${?}"
    fi
}

check_user_type(){
    local type="${1}"
    if [[ "${type}" == "${gadmin}" ]];then
        :
    elif [[ "${type}" == "${guser}" ]];then
        :
    elif [[ "${type}" == "${grmgr}" ]];then
        :
    elif [[ "${type}" == "${gdplr}" ]];then
        :
    elif [[ "${type}" == "${gcadmin}" ]];then
        :
    else
        echo "Wrong type of user: ${type}"
        help
    fi
}

delete_svc_account(){
    local user="${1}"
    local ns="${2}"
    kubectl delete sa -n ${ns} ${user} 2>&1 >/dev/null
    if [[ $? != 0 ]];then
        echo "Could not delete the user.Error occured"
        exit 1
    fi
    delete_svc_binds ${user}
    if [[ "${?}" == 0 ]];then
        echo "User ${user} deleted"
        return 0
    else
        echo "User ${user} did not deleted.Error occured."
        return 1
    fi
}

delete_svc_binds(){
    local user="${1}"
    for i in $(kubectl get rolebindings --all-namespaces  \
    | grep ${user} | awk '{print $1}' | xargs);do
        kubectl delete rolebinding -n ${i} ${user} 2>&1 >/dev/null
    done
    for i in $(kubectl get clusterrolebindings --all-namespaces  \
    | grep ${user} | awk '{print $1}' | xargs);do
        kubectl delete clusterrolebinding -n ${i} ${user} 2>&1 >/dev/null
    done
    return ${?}
}

return_user_token(){
    global_user_token=''
    local user="${1}"
    local ns="${2}"
    local user_secret="$(kubectl describe sa -n ${ns} ${user} | grep -w "Tokens" | awk '{print $2}')"
    local user_token="$(kubectl describe secret -n ${ns} ${user_secret} | grep -w "token:" | awk '{print $2}')"
    global_user_token="${user_token}"

}
check_if_user_exists(){
    local user="$1"
    local ns="${2}"
    kubectl get sa ${user} -n ${ns} --no-headers 2>&1 >/dev/null
    exit_code="${?}"
    return ${exit_code}
}
create_user_config_file(){
    local user="${1}"
    local ns="${2}"
    local ca="$(kubectl config view --flatten --minify | grep -w "certificate-authority-data:" | awk '{print $2}')"
    local token="${global_user_token}"
    local srv="$(kubectl config view --flatten --minify | grep -w "server:" | awk '{print $2}')"
    local cluster="$(kubectl config view --flatten --minify | grep -w "cluster:" | tail -n+2 | awk '{print $2}')"
    echo "
apiVersion: v1
kind: Config
users:
- name: ${user}
  user:
    token: ${token}
clusters:
- cluster:
    certificate-authority-data: ${ca}
    server: ${srv}
  name: ${cluster}
contexts:
- context:
    cluster: ${cluster}
    namespace: ${ns}
    user: ${user}
  name: ${user}-context
current-context: ${user}-context" > "${user}-config"
echo "You can find the kubectl config file at ${PWD}/${user}-config "
}

main(){
    local what_to_do="${1}"
    local user="${2}"
    local ns="${3}"
    local type="${4}"
    shift
    shift
    shift
    shift
    local rest="$*"
    if [[ "${what_to_do}" == create ]];then
        check_user_type "${type}"
        check_if_user_exists "${user}" "$ns" 2>/dev/null
        if [[ ${?} == 1 ]];then
            :
        else
            echo "User ${user} already exists."
            exit 1
        fi
        if [[ ${rest} == '' ]];then
            create_user "${user}" "${ns}"
            create_bind "${user}" "${type}" "${ns}"
            return_user_token ${user} ${ns}
            create_user_config_file "${user}" "${ns}"
            echo "User token is: ${global_user_token}"
        else
            create_user "${user}" "${ns}"
            ## Create bind for his standard namespace first
            create_bind "${user}" "${type}" "${ns}"
            ## And for the rest too
            for i in ${rest};do
            create_bind "${user}" "${type}" "${ns}" "${i}"
            done
            return_user_token ${user} ${ns}
            create_user_config_file "${user}" "${ns}"
            echo "User token is: ${global_user_token}"
        fi
    elif [[ "${what_to_do}" == delete ]];then
        check_if_user_exists "${user}" "$ns"
        if [[ "${?}" == 1 ]];then
            echo "User ${user} does not exist"
            exit 1
        fi
        delete_svc_account "${user}" "${ns}"
    elif [[ "${what_to_do}" == config ]];then
        check_if_user_exists "${user}" "$ns"
	    if [[ "${?}" == 1 ]];then
            echo "User ${user} does not exist"
            exit 1
        fi
	    return_user_token ${user} ${ns}
        create_user_config_file "${user}" "${ns}"
    else
        help
    fi      
}

main "${@}"
