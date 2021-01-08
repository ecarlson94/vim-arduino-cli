if exists('b:did_arduino_ftplugin')
  finish
endif
let b:did_arduino_ftplugin = 1
if !exists('g:arduino_did_initialize')
  call arduino#LoadCache()
  call arduino#InitializeConfig()
  let g:arduino_did_initialize = 1
endif

" Use C rules for indentation
setl cindent


command! -buffer -bar -nargs=? ArduinoChooseBoard call arduino#ChooseBoard(<f-args>)
command! -buffer -bar -nargs=? ArduinoChooseProgrammer call arduino#ChooseProgrammer(<f-args>)
command! -buffer -bar -nargs=? ArduinoLibSearch call arduino#LibSearch(<f-args>)
command! -buffer -bar -nargs=? ArduinoLibInstall call arduino#LibInstall(<f-args>)
command! -buffer -bar ArduinoCompile call arduino#Compile()
command! -buffer -bar ArduinoUpload call arduino#Upload()
command! -buffer -bar ArduinoAttach call arduino#Attach()
command! -buffer -bar ArduinoUploadAndAttach call arduino#UploadAndAttach()
command! -buffer -bar ArduinoGetInfo call arduino#GetInfo()
command! -buffer -bar ArduinoInfo call arduino#GetInfo()
command! -buffer -bar -nargs=? ArduinoChoosePort call arduino#ChoosePort(<f-args>)
