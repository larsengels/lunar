# audit_aws_iam
#
# Refer to http://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
# Refer to Section(s) 1.1  Page(s) 10-1  CIS AWS Foundations Benchmark v1.1.0
# Refer to Section(s) 1.18 Page(s) 46-57 CIS AWS Foundations Benchmark v1.1.0
# Refer to https://www.cloudconformity.com/conformity-rules/IAM/unused-iam-group.html
# Refer to https://www.cloudconformity.com/conformity-rules/IAM/unused-iam-user.html
# Refer to https://www.cloudconformity.com/conformity-rules/IAM/iam-user-policies.html
#.

audit_aws_iam () {
  # Root account should only be used sparingly, admin functions and responsibilities should be delegated
	aws iam generate-credential-report 2>&1 > /dev/null
	date_test=`date +%Y-%m`
	last_login=`aws iam get-credential-report --query 'Content' --output text | $base64_d | cut -d, -f1,5,11,16 | grep -B1 '<root_account>' |cut -f2 -d, |cut -f1,2 -d- |grep '[0-9]'`
	total=`expr $total + 1`
	if [ "$date_test" = "$last_login" ]; then
		insecure=`expr $insecure + 1`
    echo "Warning:   Root account appears to be being used regularly [$insecure Warnings]"
	else
		secure=`expr $secure + 1`
    echo "Secure:    Root account does not appear to be being used frequently [$secure Passes]"
	fi
  # Check to see if there is an IAM master role
	total=`expr $total + 1`
	check=`aws iam get-role --role-name $aws_iam_master_role 2> /dev/null`
	if [ "$check" ]; then 
		secure=`expr $secure + 1`
    echo "Secure:    IAM Master role $aws_iam_master_role exists [$secure Passes]"
	else
		insecure=`expr $insecure + 1`
    echo "Warning:   IAM Master role $aws_iam_master_role does not exist [$insecure Warnings]"
    funct_verbose_message "" fix
    funct_verbose_message "cd aws" fix
    funct_verbose_message "aws iam create-role --role-name $aws_iam_master_role --assume-role-policy-document file://account-creation-policy.json" fix
    funct_verbose_message "aws iam put-role-policy --role-name $aws_iam_master_role --policy-name $aws_iam_master_role --policy-document file://iam-master-policy.json" fix
    funct_verbose_message "" fix
	fi
  # Check there is an IAM manager role
	total=`expr $total + 1`
	check=`aws iam get-role --role-name $aws_iam_manager_role 2> /dev/null`
	if [ "$check" ]; then 
		secure=`expr $secure + 1`
    echo "Secure:    IAM Manager role $aws_iam_manager_role exists [$secure Passes]"
	else
		insecure=`expr $insecure + 1`
    echo "Warning:   IAM Manager role $aws_iam_manager_role does not exist [$insecure Warnings]"
    funct_verbose_message "" fix
    funct_verbose_message "cd aws" fix
    funct_verbose_message "aws iam create-role --role-name $aws_iam_master_role --assume-role-policy-document file://account-creation-policy.json" fix
    funct_verbose_message "aws iam put-role-policy --role-name $aws_iam_manager_role --policy-name $aws_iam_manager_role --policy-document file://iam-manager-policy.json" fix
    funct_verbose_message "" fix
	fi
  # Check groups have members
  groups=`aws iam list-groups --query 'Groups[].GroupName' --output text`
  for group in $groups; do
    total=`expr $total + 1`
    users=`aws iam get-group --group-name $group --query "Users" --output text`
    if [ "$users" ]; then
      secure=`expr $secure + 1`
      echo "Secure:    IAM group $group is not empty [$secure Passes]"
    else
      insecure=`expr $insecure + 1`
      echo "Warning:   IAM group $group is empty [$insecure Warnings]"
    fi
  done
  users=`aws iam list-users --query 'Users[].UserName' --output text`
  for user in $users; do
    # Check for inactive users
    total=`expr $total + 1`
    check=`aws iam list-access-keys --user-name $user --query "AccessKeyMetadata" --output text`
    if [ "$check" ]; then
      secure=`expr $secure + 1`
      echo "Secure:    IAM user $user is active [$secure Passes]"
    else
      insecure=`expr $insecure + 1`
      echo "Warning:   IAM user $user is not active [$insecure Warnings]"
      funct_verbose_message "" fix
      funct_verbose_message "aws iam delete-user --user-name $user" fix
      funct_verbose_message "" fix
    fi
    # Check users do not have attached policies, they should be members of groups which have those policies
    policies=`aws iam list-attached-user-policies --user-name $user --query "AttachedPolicies[].PolicyArn" --output text`
    if [ "$policies" ]; then
      for policy in $policies; do
        total=`expr $total + 1`
        insecure=`expr $insecure + 1`
        echo "Warning:   IAM user $user has attached policy $policy [$insecure Warnings]"
        funct_verbose_message "" fix
        funct_verbose_message "aws iam detach-user-policy --user-name $user --policy-arn $policy" fix
        funct_verbose_message "" fix
      done
    else
      total=`expr $total + 1`
      secure=`expr $secure + 1`
      echo "Secure:    IAM user $user does not have attached policies [$secure Passes]"
    fi
  done
}

