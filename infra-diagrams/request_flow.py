#!/usr/bin/env python3

from diagrams import Diagram, Cluster, Edge
from diagrams.generic.os import Ubuntu
from diagrams.generic.network import Firewall, Router
from diagrams.k8s.compute import Pod
from diagrams.k8s.network import Service, Ingress
from diagrams.generic.compute import Rack
from diagrams.onprem.client import User
from diagrams.onprem.network import Internet
from diagrams.generic.blank import Blank

def create_request_flow_diagram():
    """Create a clean request flow diagram showing the infrastructure"""
    
    with Diagram(
        "Request Flow: www.matthewjmyrick.com",
        filename="diagrams/request_flow",
        show=False,
        direction="LR",
        graph_attr={
            "fontsize": "20",
            "bgcolor": "white",
            "pad": "0.5",
            "rankdir": "LR",
            "concentrate": "false"
        }
    ):
        
        # User/Client
        user = User("User\nBrowser")
        
        # DNS Resolution
        dns = Router("GoDaddy\nDNS")
        
        # Internet representation
        internet = Internet("Public\nInternet")
        
        # Tailscale Funnel (using firewall as proxy)
        tailscale = Firewall("Tailscale\nFunnel")
        
        # Server infrastructure
        with Cluster("Ubuntu Server (100.96.78.104)\nPrivate Tailscale Network"):
            server = Ubuntu("Ubuntu\nServer")
            
            with Cluster("K3s Kubernetes Cluster"):
                with Cluster("hello-world namespace"):
                    # Tailscale Ingress
                    ts_ingress = Ingress("Tailscale\nIngress")
                    
                    # Service
                    hello_service = Service("hello-world\nService")
                    
                    # Pod
                    hello_pod = Pod("Hello World\nPod (nginx)")
        
        # Request flow (numbered steps)
        user >> Edge(label="1. www.matthewjmyrick.com", style="bold", color="blue") >> dns
        dns >> Edge(label="2. Tailscale IP", style="bold", color="green") >> user
        user >> Edge(label="3. HTTPS Request", style="bold", color="purple") >> internet
        internet >> Edge(label="4. Public Traffic", style="bold", color="orange") >> tailscale
        tailscale >> Edge(label="5. Encrypted Tunnel", style="bold", color="red") >> server
        server >> Edge(label="6. Internal Request", style="bold", color="darkblue") >> ts_ingress
        ts_ingress >> Edge(label="7. Route", style="bold", color="darkgreen") >> hello_service
        hello_service >> Edge(label="8. Forward", style="bold", color="darkred") >> hello_pod
        
        # Response flow (dashed lines)
        hello_pod >> Edge(label="Response", style="dashed", color="gray") >> hello_service
        hello_service >> Edge(style="dashed", color="gray") >> ts_ingress
        ts_ingress >> Edge(style="dashed", color="gray") >> server
        server >> Edge(style="dashed", color="gray") >> tailscale
        tailscale >> Edge(style="dashed", color="gray") >> internet
        internet >> Edge(style="dashed", color="gray") >> user

def create_security_diagram():
    """Create a security model diagram"""
    
    with Diagram(
        "Security Model: Public vs Private Access",
        filename="diagrams/security_model", 
        show=False,
        direction="TB",
        graph_attr={
            "fontsize": "20",
            "bgcolor": "white",
            "pad": "0.5"
        }
    ):
        
        # Public zone
        with Cluster("Public Internet", graph_attr={"bgcolor": "lightcoral", "style": "filled"}):
            public_user = User("Any User")
            public_access = Blank("Only Access:\nwww.matthewjmyrick.com\nPort 443 (HTTPS)")
        
        # Tailscale barrier
        firewall = Firewall("Tailscale\nFunnel\n(Selective Exposure)")
        
        # Private zone  
        with Cluster("Private Tailscale Network", graph_attr={"bgcolor": "lightgreen", "style": "filled"}):
            with Cluster("Blocked from Public"):
                ssh_access = Blank("SSH (Port 22)\nK8s API\nOther Services\nDirect Server Access")
                
            with Cluster("Your Infrastructure"):
                server = Ubuntu("Ubuntu Server")
                k8s = Rack("K3s Cluster")
                hello_app = Pod("Hello World\nApp Only")
        
        # Connections
        public_user >> Edge(label="HTTPS Only", color="red") >> firewall
        firewall >> Edge(label="Encrypted Tunnel", color="green") >> hello_app
        firewall >> Edge(label="❌ BLOCKED", color="red", style="dashed") >> ssh_access

if __name__ == "__main__":
    print("Generating request flow diagram...")
    create_request_flow_diagram()
    print("✅ Request flow diagram saved as: diagrams/request_flow.png")
    
    print("Generating security model diagram...")
    create_security_diagram()
    print("✅ Security model diagram saved as: diagrams/security_model.png")
    
    print("\nDiagrams generated successfully!")
    print("View them in the diagrams/ directory.")