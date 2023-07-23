# Abre el archivo de conf
kubectl edit -n kube-system configmap/aws-auth

#Agregar a la altura de mapRoles
  mapUsers: |
    - userarn: arn:aws:iam::265198653890:user/caapolo
      username: caapolo
      groups:
      - system:masters