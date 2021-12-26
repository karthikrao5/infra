
## KubeConfig

After running 
```
terraform apply
```

run 
```
aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

to grab the new kubeconfig and add it to your local list for Lens to pick up
