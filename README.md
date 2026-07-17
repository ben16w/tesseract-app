# roles-app / roles-network / roles-system

This project contains Ansible roles for tesseract.

## Installation

To install the collection, run the command below. This will install the collection from the git repository to the default collection location.

```sh
ansible-galaxy collection install git+https://github.com/ben16w/<collection>.git
```

## Usage

You can use these roles in your Ansible playbooks. For example:

```yaml
- hosts: all
  roles:
    - tesseract.<collection>.<role>
```

## Development

Run the setup script to install dependencies and download the Justfile:

```sh
./setup.sh
```

Set up the virtual environment:

```sh
just install-venv
```

To run the tests, execute the following command:

```sh
just test
```

## License

This project is licensed under the Unlicense. See the [LICENSE](LICENSE) file for details.

## Authors

- Ben Wadsworth
