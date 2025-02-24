# roles-app

This project contains Ansible roles for managing application configurations and services for tesseract.

## Installation

To install the collection, run the command below. This will install the collection from the git repository to the default collection location.

```sh
ansible-galaxy collection install git+https://github.com/ben16w/tesseract-app.git
```

## Usage

You can use these roles in your Ansible playbooks. For example:

```yaml
- hosts: all
  roles:
    - tesseract.app.docker
```

## Development

Install the required system packages:

```sh
sudo apt install make python3 python3-pip python3-venv
```

Set up the virtual environment and install the required Python packages:

```sh
make install-venv
```

To run the tests, execute the following command:

```sh
make test
```

## License

This project is licensed under the Unlicense. See the [LICENSE](LICENSE) file for details.

## Authors

- Ben Wadsworth
