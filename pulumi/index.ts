import * as pulumi from "@pulumi/pulumi";
import * as awsx from "@pulumi/awsx";
import * as aws from "@pulumi/aws";
import * as eks from "@pulumi/eks";
import * as k8s from "@pulumi/kubernetes";

// Grab some values from the Pulumi configuration (or use default values)
const config = new pulumi.Config();
const minClusterSize = config.getNumber("minClusterSize") || 3;
const maxClusterSize = config.getNumber("maxClusterSize") || 6;
const desiredClusterSize = config.getNumber("desiredClusterSize") || 3;
const eksNodeInstanceType = config.get("eksNodeInstanceType") || "t3.medium";
const vpcNetworkCidr = config.get("vpcNetworkCidr") || "10.0.0.0/16";

// Create a new VPC
const eksVpc = new awsx.ec2.Vpc("eks-vpc", {
  subnetSpecs: [{}],
  enableDnsHostnames: true,
  cidrBlock: vpcNetworkCidr,
});

// Create the EKS cluster
const eksCluster = new eks.Cluster("eks-cluster", {
  // Put the cluster in the new VPC created earlier
  vpcId: eksVpc.vpcId,
  // Public subnets will be used for load balancers
  publicSubnetIds: eksVpc.publicSubnetIds,
  // Private subnets will be used for cluster nodes
  privateSubnetIds: eksVpc.privateSubnetIds,
  // Change configuration values to change any of the following settings
  instanceType: eksNodeInstanceType,
  desiredCapacity: desiredClusterSize,
  minSize: minClusterSize,
  maxSize: maxClusterSize,
  // Do not give the worker nodes public IP addresses
  nodeAssociatePublicIpAddress: false,
  // Uncomment the next two lines for a private cluster (VPN access required)
  // endpointPrivateAccess: true,
  // endpointPublicAccess: false
});

// Export some values for use elsewhere
export const kubeconfig = eksCluster.kubeconfig;
export const vpcId = eksVpc.vpcId;

// create a new namespace for k8s resources
const consulNamespace = new k8s.core.v1.Namespace(
  "namespaceConsul",
  {
    metadata: {
      name: "consul",
    },
  },
  { provider: eksCluster.provider }
);
const grafanaNamespace = new k8s.core.v1.Namespace(
  "namespaceGrafana",
  {
    metadata: {
      name: "grafana",
    },
  },
  { provider: eksCluster.provider }
);

const grafana = new k8s.helm.v3.Chart(
  "grafana",
  {
    chart: "grafana",
    values: { minio: { enabled: true } },
    namespace: "grafana",
    fetchOpts: {
      repo: "https://grafana.github.io/helm-charts",
    },
  },
  {
    providers: { kubernetes: eksCluster.provider },
    dependsOn: [grafanaNamespace],
  }
);

const nginxIngress = new k8s.helm.v3.Chart(
  "nginx-ingress",
  {
    chart: "nginx-ingress",
    fetchOpts: {
      repo: "https://charts.helm.sh/stable",
    },
  },
  { providers: { kubernetes: eksCluster.provider } }
);

const consul = new k8s.helm.v3.Chart(
  "consul",
  {
    chart: "consul",
    namespace: "consul",
    fetchOpts: {
      repo: "https://charts.helm.sh/stable",
    },
  },
  {
    providers: { kubernetes: eksCluster.provider },
    dependsOn: [consulNamespace],
  }
);

const domainName = "kubernetes.quest";
const hostedZone = new aws.route53.Zone("my-zone", {
  name: domainName,
});

// Create DNS records as needed (e.g., A or CNAME records)
const dnsRecord = new aws.route53.Record("my-record", {
  name: "", // Replace with your subdomain or leave empty for root domain
  type: "CNAME", // Change to CNAME or other record types as needed
  zoneId: hostedZone.zoneId,
  ttl: 300, // Time to live for DNS record (optional)
  records: [eksCluster.eksClusterIngressRule.], // Value to add to DNS record
});
