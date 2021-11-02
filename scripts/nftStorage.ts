import fs from 'fs';
import { NFTStorage, File } from 'nft.storage'
import { ethers } from 'hardhat';

async function main() {
    const hnbox = await ethers.getContractAt('HNBox', '0x643a7a48FbB612938b7F08552936D3443F1b1b6c');
    
    hnbox.on('SpawnHns', (user, boxesLength, hnIds, event) => {
        console.log(hnIds);
    });

    // const length = 500;

    // const image = [];
    // for (let j = 0; j < length; j++) {
    //     getHnImg(j, )
    //     const buffer = Buffer.from();
    //     image.push(new File([buffer], `${j + 1}.jpg`, { type: 'image/jpg' }));
    // }
    // const newImageCID = await client.storeDirectory(image);
    // console.log('New Image CID:', newImageCID);

    // const metadata = [];
    // const metadataLength = fs.readdirSync(`nft/${nft[i].name}/metadata`).length;
    // for (let j = 0; j < metadataLength; j++) {
    //     const json = JSON.parse(fs.readFileSync(`nft/${nft[i].name}/metadata/${j + 1}.json`).toString());
    //     json.image = json.image.replace('{cid}', newImageCID);
    //     metadata.push(new File([JSON.stringify(json)], `${j + 1}.json`));
    // }
    // const newMetadataCID = await client.storeDirectory(metadata);
    // console.log('New Metadata CID:', newMetadataCID);

    // const oldImageCID = await nft[i].contract.imageCID();
    // const oldMetadataCID = await nft[i].contract.metadataCID();
    // const transction = await nft[i].contract.setCID(newImageCID, newMetadataCID, 'https://ipfs.io/ipfs/', '/{id}.json');
    // await transction.wait(5);
    // const newURI = await nft[i].contract.uri(0);
    // console.log('New URI:', newURI);

    // if (oldImageCID && oldImageCID != newImageCID) {
    //     await client.delete(oldImageCID);
    //     console.log('Delete Old Image CID:', oldImageCID);
    // }
    // if (oldMetadataCID && oldMetadataCID != newMetadataCID) {
    //     await client.delete(oldMetadataCID);
    //     console.log('Delete Old Metadata CID:', oldMetadataCID);
    // }
}

main();
