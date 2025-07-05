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
