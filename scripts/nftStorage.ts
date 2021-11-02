import fs from 'fs';
import { NFTStorage, File } from 'nft.storage'
import { ethers } from 'hardhat';
import { BigNumber, utils } from 'ethers';
import sharp from 'sharp';

// const client = new NFTStorage({ token: process.env.NFT_STORAGE_API_KEY as string });

function getRandomNumber(hnId: number, slot: string, base: number, range: number) {
    return BigNumber.from(utils.solidityKeccak256(['uint256', 'string'], [hnId, slot])).mod(range).add(base).toNumber();
}

async function composite(hnId: number) {
    const level = 1;
    const hnClass = getRandomNumber(hnId, 'class', 1, 4);

    const bg = sharp(`nft/material/bg/${level}.png`).toBuffer();

    const materials = [
        `nft/materials/class${hnClass}/effect/bg/${level}.png`,
        `nft/materials/class${hnClass}/hero.png`,
        `nft/materials/class${hnClass}/item1/${getRandomNumber(hnId, 'item1', 1, 10)}.png`,
        `nft/materials/class${hnClass}/item2/${getRandomNumber(hnId, 'item2', 1, 10)}.png`,
        `nft/materials/class${hnClass}/effect/hero/${level}.png`,
        `nft/materials/class${hnClass}/info.png`
    ].reduce(async (input, overlay) => {
        return await sharp(await input).composite([{ input: overlay }]).toBuffer();
    }, bg);

    const composited = await sharp(await materials).sharpen().webp({ quality: 90 }).toBuffer();

    fs.writeFileSync(`nft/images/hashlandnft${hnId}.png`, composited);
}

function compositeBatch(start: number, length: number) {
    for (let i = start; i < length; i++) {
        composite(i);
    }
}

async function main() {
    const length = 1000;

    // compositeBatch(0, length);

    // const hnbox = await ethers.getContractAt('HNBox', '0x643a7a48FbB612938b7F08552936D3443F1b1b6c');

    // const images = [];
    // for (let i = 0; i < length; i++) {
    //     const buffer = Buffer.from(fs.readFileSync(`nft/composited/hashlandnft${i}.png`));
    //     images.push(new File([buffer], `${i}.png`, { type: 'image/png' }));
    // }
    // const newImageCID = await client.storeDirectory(images);
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
