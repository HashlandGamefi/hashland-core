import OSS from 'ali-oss';
import { BigNumber, utils } from 'ethers';
import { ethers } from 'hardhat';
import sharp from 'sharp';

const maxLevel = 5;
const hnAddr = '0xe0bC28c693315dB601046BfB01c231DDf16145B8';

const client = new OSS({
    region: 'oss-ap-southeast-1',
    accessKeyId: process.env.accessKeyId as string,
    accessKeySecret: process.env.accessKeySecret as string,
    bucket: 'hashlandgamefi',
});

function getRandomNumber(hnId: number, slot: string, base: number, range: number) {
    return BigNumber.from(utils.solidityKeccak256(['uint256', 'string'], [hnId, slot])).mod(range).add(base).toNumber();
}

async function main() {
    const hn = await ethers.getContractAt('HN', hnAddr);

    async function generateImage(hnId: number, level: number) {
        const hnClass = getRandomNumber(hnId, 'class', 1, 4);
        const hashrates = await hn.getHashrates(hnId);

        const hashrateText = Buffer.from(`
            <svg width="400" height="500">
                <style>
                    .title { fill: #FFF; font-size: 14px; font-weight: bold; font-family: Poppins; }
                </style>
                <text x="56%" y="11%" text-anchor="middle" class="title">${(hashrates[0] / 1e4).toFixed(4)}</text>
                <text x="76%" y="11%" text-anchor="middle" class="title">${(hashrates[1] / 1e4).toFixed(4)}</text>
            </svg>
        `);

        const heroItems = [
            `nft/class${hnClass}/hero.png`,
            `nft/class${hnClass}/item1/${getRandomNumber(hnId, 'item1', 1, 10)}.png`,
            `nft/class${hnClass}/item2/${getRandomNumber(hnId, 'item2', 1, 10)}.png`,
            `nft/class${hnClass}/item3/${getRandomNumber(hnId, 'item3', 1, 10)}.png`,
            `nft/class${hnClass}/item4/${getRandomNumber(hnId, 'item4', 1, 10)}.png`,
            `nft/class${hnClass}/item5/${getRandomNumber(hnId, 'item5', 1, 10)}.png`,
            `nft/class${hnClass}/item6/${getRandomNumber(hnId, 'item6', 1, 10)}.png`,
            `nft/class${hnClass}/item7/${getRandomNumber(hnId, 'item7', 1, 10)}.png`,
        ];

        const heroItemsByLevel = [
            [],
            [heroItems[0], heroItems[1], heroItems[2]],
            [heroItems[0], heroItems[3], heroItems[1], heroItems[2]],
            hnClass == 4 ? [heroItems[0], heroItems[1], heroItems[3], heroItems[4], heroItems[2]] : [heroItems[0], heroItems[3], heroItems[4], heroItems[1], heroItems[2]],
            [heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6]],
            hnClass == 2 ? [heroItems[7], heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6]] : [heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6], heroItems[7]],
        ];

        const bg = sharp(`nft/bg/${level}.png`).toBuffer();
        const materials = [
            `nft/class${hnClass}/effect/bg/${level}.png`,
            ...heroItemsByLevel[level],
            `nft/class${hnClass}/effect/hero/${level}.png`,
            `nft/class${hnClass}/info.png`,
            hashrateText,
        ].reduce(async (input, overlay) => {
            return await sharp(await input).composite([{ input: overlay }]).toBuffer();
        }, bg);

        const composited = await sharp(await materials).sharpen().webp({ quality: 90 }).toBuffer();

        try {
            const result = await client.put(`nft/images/hashland-nft-${hnId}-${level}.png`, composited);
            console.log(result.url);
        } catch (e) {
            console.log(e);
        }
    }

    async function generateImages(start: number, end: number) {
        return new Promise(resolve => {
            let count = 0;
            for (let hnId = start; hnId < end; hnId++) {
                for (let level = 1; level <= maxLevel; level++) {
                    generateImage(hnId, level).then(() => {
                        count++;
                        if (count == (end - start) * maxLevel) {
                            resolve(true);
                        }
                    });
                }
            }
        });
    }

    async function generateMetadata(imagesCid: string, hnId: number, level: number) {
        const hnClass = getRandomNumber(hnId, 'class', 1, 4);
        const hashrates = await hn.getHashrates(hnId);

        const className = ['Cavalryman', 'Holy', 'Blade', 'Hex'];
        const heroName = ['Main Tank', 'Lady', 'Hunter', `Gul'dan`];
        const fileName = `hashland-nft-${hnId}-${level}`;

        const metadata = {
            name: `Hashland NFT #${hnId}`,
            description: 'Have you ever imagined an NFT with BTC hashrate? HashLand did it, and now he brings the first series of NFT - I AM MT.',
            image: `${imagesCid}/${fileName}.png`,
            attributes: [
                {
                    trait_type: 'Ip',
                    value: `I AM MT`,
                },
                {
                    trait_type: 'Series',
                    value: 'Basic',
                },
                {
                    trait_type: 'Level',
                    value: level,
                },
                {
                    trait_type: 'Class',
                    value: className[hnClass - 1],
                },
                {
                    trait_type: 'Hero',
                    value: heroName[hnClass - 1],
                },
                {
                    trait_type: 'HC_Hashrate',
                    value: (hashrates[0] / 1e4).toFixed(4),
                },
                {
                    trait_type: 'BTC_Hashrate',
                    value: (hashrates[1] / 1e4).toFixed(4),
                },
            ],
        }

        try {
            const result = await client.put(`nft/metadatas/${fileName}.json`, Buffer.from(JSON.stringify(metadata)));
            console.log(result.url);
        } catch (e) {
            console.log(e);
        }
    }

    function generateMetadatas(imagesCid: string, start: number, end: number) {
        return new Promise(resolve => {
            let count = 0;
            for (let hnId = start; hnId < end; hnId++) {
                for (let level = 1; level <= maxLevel; level++) {
                    generateMetadata(imagesCid, hnId, level).then(() => {
                        count++;
                        if (count == (end - start) * maxLevel) {
                            resolve(true);
                        }
                    });
                }
            }
        });
    }

    hn.on('SpawnHn', async (to, hnId, event) => {
        const level = await hn.level(hnId);
        console.log('');
        console.log(`Spawn level-${level} NFT #${hnId} to ${to}`);

        generateImage(hnId, level);
        generateMetadata('https://cdn.hashland.com/nft/images', hnId, level);
    });

    hn.on('SetHashrates', async (hnId, hashrates, event) => {
        const level = await hn.level(hnId);
        console.log('');
        console.log(`Set level-${level} NFT #${hnId} hashrates to [${(hashrates[0] / 1e4).toFixed(4)}, ${(hashrates[1] / 1e4).toFixed(4)}]`);

        generateImage(hnId, level);
        generateMetadata('https://cdn.hashland.com/nft/images', hnId, level);
    });

    // const start = 0;
    // const end = 1000;
    // const batch = 50;

    // for (let i = start / batch; i < end / batch; i++) {
    //     await generateImages(i * batch, (i + 1) * batch);
    //     console.log(`${(i + 1) * batch} / ${end}`);
    // }

    // for (let i = start / batch; i < end / batch; i++) {
    //     await generateMetadatas('https://cdn.hashland.com/nft/images', i * batch, (i + 1) * batch);
    //     console.log(`${(i + 1) * batch} / ${end}`);
    // }
}

main();
