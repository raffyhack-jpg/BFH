import json, plistlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    prefix='Payload/PocketFront.app/'
    info=plistlib.loads(z.read(prefix+'Info.plist'))
    binary=z.read(prefix+info['CFBundleExecutable'])
    assert len(binary)>4096, 'Missing compiled executable'
    assert binary[:4] in [bytes.fromhex(s) for s in ['cffaedfe','feedfacf','cafebabe','bebafeca']], 'Not a Mach-O binary'
    assert not any('/_CodeSignature/' in n for n in z.namelist()), 'Signature found'
    assert info['CFBundlePackageType']=='APPL'
    assert prefix+'Assets/UI/logo.png' in z.namelist() and prefix+'Assets/UI/menu.png' in z.namelist(), 'Original menu artwork missing'
    world=json.loads(z.read(prefix+'Assets/OriginalWorld/world.json'))
    assert len(world['instances'])>500 and len(world['weapons'])==6, 'Original world was not bundled'
    for mesh in world['meshAssets'].values():
        assert prefix+'Assets/OriginalWorld/'+mesh['file'] in z.namelist(), 'Original mesh missing from IPA'
        for part in mesh['parts']:
            if part['texture']: assert prefix+'Assets/OriginalWorld/'+part['texture'] in z.namelist(), 'Original texture missing from IPA'
print('IPA structure and executable verified. Device signing is still required.')
