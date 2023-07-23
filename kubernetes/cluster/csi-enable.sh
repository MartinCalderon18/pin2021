echo '-------Enable CSI on an EKS Cluster'

AWS_REGION=us-east-1
my_eks_cluster=tcss702-eks

eksctl utils associate-iam-oidc-provider --cluster $my_eks_cluster --approve --region $AWS_REGION
# aws iam detach-role-policy --role-name AmazonEKS_EBS_CSI_DriverRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
# aws iam delete-role --role-name AmazonEKS_EBS_CSI_DriverRole 

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster $my_eks_cluster \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --role-only \
  --role-name AmazonEKS_EBS_CSI_DriverRole

myaccount_id=$(aws sts get-caller-identity --query "Account" | sed -e 's/\"//g')
eksctl create addon --name aws-ebs-csi-driver --cluster $my_eks_cluster --service-account-role-arn arn:aws:iam::$myaccount_id:role/AmazonEKS_EBS_CSI_DriverRole --force

kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/examples/kubernetes/dynamic-provisioning/manifests/storageclass.yaml

kubectl annotate sc gp2 storageclass.kubernetes.io/is-default-class-
kubectl annotate sc ebs-sc storageclass.kubernetes.io/is-default-class=true