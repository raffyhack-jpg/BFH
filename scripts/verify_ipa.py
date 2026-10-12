import plistlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    prefix='Payload/PocketFront.app/'
    info=plistlib.loads(z.read(prefix+'Info.plist'))
    binary=z.read(prefix+info['CFBundleExecutable'])
    assert len(binary)>4096, 'Missing compiled executable'
    assert binary[:4] in [bytes.fromhex(s) for s in ['cffaedfe','feedfacf','cafebabe','bebafeca']], 'Not a Mach-O binary'
    assert not any('/_CodeSignature/' in n for n in z.namelist()), 'Signature found'
    assert info['CFBundlePackageType']=='APPL'
print('IPA structure and executable verified. Device signing is still required.')
