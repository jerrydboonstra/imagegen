# Contributing

Issues and pull requests are welcome.

- Keep a change small: one fix or one idea per pull request.
- Add no new dependencies. imagegen needs Pillow for box mode and nothing else.
- Run the three offline tests before you open a pull request. They need a Python 3 with Pillow:
  - `bash tests/box-guarantee.sh`
  - `bash tests/box-guarantee-nopillow.sh`
  - `bash tests/doctor.sh`
- To report a bug or suggest something, open an issue and fill in the form.
- To report a security problem, see [SECURITY.md](SECURITY.md).

imagegen is released under the MIT licence (`LICENSE` at the root of this repo). By sending a change you agree that it is released under the same licence.
