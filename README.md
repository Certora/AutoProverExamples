# AutoProver Examples

Example projects for [AutoProver](https://github.com/Certora/AutoProver), the multi-agent
pipeline that automatically generates and verifies CVL specifications for Solidity contracts.

Each example is a self-contained project with the inputs AutoProver expects: a project root, a
main contract (`path/to/Contract.sol:ContractName`), and a design document describing the system.

## Examples

| Project | Description |
|---|---|
| `SmokeTest` | The minimal end-to-end example: a single contract whose one function returns `42`. Used to exercise the pipeline with the smallest possible input. |

## Usage

Point AutoProver at one of these projects. From an AutoProver checkout:

```bash
scripts/autoprove AutoProverExamples/SmokeTest src/Answer.sol:Answer design.md --cloud
```

See the [AutoProver README](https://github.com/Certora/AutoProver) for setup and full usage.

## License

GPL-3.0. See [LICENSE](LICENSE).
