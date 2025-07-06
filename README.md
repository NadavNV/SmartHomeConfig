# Smart Home Devices Management

This is the main repository for a system to view and manage Smart Home devices, such as lights, water heaters, or air conditioners. It is our final project in the DevSecOps course at Bar-Ilan University, by [Yarden Ziv](https://github.com/yarden-ziv), [Yaniv Naor](https://github.com/yaniv-naor), and [Nadav Nevo](https://github.com/NadavNV).

It is made up of three micro-services:

- Flask-based backend ([repository](https://github.com/NadavNV/SmartHomeBackend))
- React-based dashboard ([repository](https://github.com/NadavNV/SmartHomeDashboard))
- Python-based device simulator ([repository](https://github.com/NadavNV/SmartHomeSimulator))

As well as monitoring and CI/CD (in this repository).

## Technologies Used

| Layer                | Technology              |
| -------------------- | ----------------------- |
| **API**              | Python3 • Flask         |
| **Database**         | MongoDB hosted on Atlas |
| **Frontend**         | React • Vite • nginx    |
| **Containerization** | Docker • Docker Hub     |
| **Orchestration**    | Kubernetes • minikube   |
| **Observability**    | Prometheus • Grafana    |
| **CI/CD**            | Jenkins                 |

## Usage

- To run the up on your machine from the pre-built images:

  - [Install minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download)
  - Start minikube: `minikube start`
  - Clone this repo and apply the kubernetes manifests. On Windows, run PowerShell as administrator:
    ```powershell
    git clone https://github.com/NadavNV/SmartHomeConfig.git
    cd kubernetes
    .\setup.ps1
    ```
    On Linux/MacOS:
    ```bash
    git clone https://github.com/NadavNV/SmartHomeConfig.git
    cd kubernetes
    sudo ./setup.sh
    ```
  - Access the dashboard on your browser at `smart-home-dashboard.local`
  - To view the monitoring through grafana run `minikube service -n smart-home smart-home-grafana-svc` and log in using username: `viewer`, password: `viewer`.

- To run the different microservices locally, please refer to their individual README files.
