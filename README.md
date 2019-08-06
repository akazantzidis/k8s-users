# k8s-users
A program to manage users as service accounts to a kubernetes cluster


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

        Create a normal user named "john" to a namespace named "doe":
        - ./k8s-users.sh create john doe user 

        Create an admin user named "john" to a namespace named "doe":
        - ./k8s-users.sh create john doe admin
                
        Create a release-manager user named "john" to a namespace named "doe":
        - ./k8s-users.sh create john doe release-manager

        Create a deploy user name "john" to a namespace  named "doe":
        - ./k8s-users.sh create john doe deployer

        You can also create a user named "john" which has access to multiple namespaces passing
        the extra namespaces as arguments at the end.
        - ./k8s-users.sh create john namespace1 user namespace2 namespace3

        Create a cluster admin user named "john" namespace is not actualy used but needed to be there so "doe":
        - ./k8s-users.sh create john doe k8scadmin 

        To delete a user named "john" to a namespace named "doe":
        - ./k8s-users.sh delete john doe

        You can also create user config file for existing user "john" of namespace "doe" as:
        - ./k8s-users.sh config john doe

# BEWARE
Some roles you have to create them by your self on your cluster
