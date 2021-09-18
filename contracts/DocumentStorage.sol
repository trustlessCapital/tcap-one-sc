// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DocumentStorage
 * @author Forest Fang (@saurfang)
 * @dev Stores IPFS (multihash) hash by address. A multihash entry is in the format
 * of <varint hash function code><varint digest size in bytes><hash function output>
 * See https://github.com/multiformats/multihash
 *
 * Currently IPFS hash is 34 bytes long with first two segments represented as a single byte (uint8)
 * The digest is 32 bytes long and can be stored using bytes32 efficiently.
 * This file is modified as per the need to TCAP One smart contracts
 */
contract DocumentStorage {
  struct Multihash {
    bytes32 digest;
    uint8 hashFunction;
    uint8 size;
  }

  mapping (uint => Multihash) private ipfsEntries;

  event IpfsEntrySet (
    uint indexed tokenId,
    bytes32 digest,
    uint8 hashFunction,
    uint8 size
  );

  event IpfsEntryDeleted (
    uint indexed tokenId
  );

  /**
   * @dev associate a multihash entry with the sender address
   * @param _tokenId token id of the NFT
   * @param _digest hash digest produced by hashing content using hash function
   * @param _hashFunction hashFunction code for the hash function used
   * @param _size length of the digest
   */
  function setIpfsEntry(uint _tokenId, bytes32 _digest, uint8 _hashFunction, uint8 _size)
  public
  {
    Multihash memory entry = Multihash(_digest, _hashFunction, _size);
    ipfsEntries[_tokenId] = entry;
    emit IpfsEntrySet(
      _tokenId, 
      _digest, 
      _hashFunction, 
      _size
    );
  }

  /**
   * @param _tokenId token id of the NFT
   * @dev deassociate any multihash entry with the token id
   */
  function ipfsClearEntry(uint _tokenId)
  public
  {
    require(ipfsEntries[_tokenId].digest != 0);
    delete ipfsEntries[_tokenId];
    emit IpfsEntryDeleted(_tokenId);
  }

  /**
   * @dev retrieve multihash entry associated with an address
   * @param _tokenId token id of the NFT
   */
  function getIpfsEntry(uint _tokenId)
  public
  view
  returns(bytes32 digest, uint8 hashfunction, uint8 size)
  {
    Multihash storage entry = ipfsEntries[_tokenId];
    return (entry.digest, entry.hashFunction, entry.size);
  }
}
