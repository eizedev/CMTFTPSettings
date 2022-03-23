# CHANGELOG

## v1.2.0 (2022-03-23)

- Added check for the used WDS/PXE Service
  - Find correct service (PXE without WDS = SCCMPxe, with WDS = WDSServer)
  - Displaying the service name also in the gui
- Find the current values of `RamDiskTFTPWindowSize` and `RamDiskTFTPBlockSize` in registry if available
  - Show current values in dropdown + info message in textbox
  - If not available, show the microsoft default values instead
- Updated margin/width of gui to fit the customized restart service button

## v1.1.1 (2021-05-16)

- Create dedicated repo
- Add CHANGELOG
- Add README
  - Add screenshot
- Add LICENSE
- Add .gitignore

## v1.1 (2021-01-27)

- Update terminology from "SCCM" to "ConfigMgr" or "CM" (where appropriate).
- Update PXE service from WDS to built-in "SccmPxe" (which is better - fite me on it!)
- Linting all the things!

## v1.0 (2016-09-30)

- [Initial script by Jörgen Nilsson.](https://ccmexec.com/2016/09/tweaking-pxe-boot-times-in-configuration-manager-1606/)
